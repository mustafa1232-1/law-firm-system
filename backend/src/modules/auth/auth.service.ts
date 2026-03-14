import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
  ConflictException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { createHash, randomInt } from 'crypto';
import { AuditService } from '../audit/audit.service';
import { UsersService } from '../users/users.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import {
  PasswordResetChallenge,
  PasswordResetChallengeDocument,
} from './schemas/password-reset-challenge.schema';
import { RefreshToken, RefreshTokenDocument } from './schemas/refresh-token.schema';
import { JwtUserPayload } from './jwt-user-payload.interface';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly auditService: AuditService,
    @InjectModel(RefreshToken.name)
    private readonly refreshTokenModel: Model<RefreshTokenDocument>,
    @InjectModel(PasswordResetChallenge.name)
    private readonly passwordResetChallengeModel: Model<PasswordResetChallengeDocument>,
  ) {}

  async register(dto: RegisterDto, ipAddress?: string) {
    const email = dto.email?.trim();
    const phone = dto.phone?.trim();
    if (!email && !phone) {
      throw new BadRequestException('Either email or phone is required');
    }

    if (email) {
      const existingEmail = await this.usersService.findByEmail(email);
      if (existingEmail) {
        throw new ConflictException('Email already used');
      }
    }

    if (phone) {
      const existingPhone = await this.usersService.findByPhone(phone);
      if (existingPhone) {
        throw new ConflictException('Phone already used');
      }
    }

    const user = await this.usersService.create(
      {
        ...dto,
        email,
        phone,
        password: dto.password,
      },
      undefined,
    );

    await this.auditService.record({
      action: 'auth.register',
      entity: 'users',
      entityId: user._id?.toString(),
      ipAddress,
      payload: {
        email: user.email ?? null,
        phone: user.phone ?? null,
      },
    });

    return this.createTokens(
      {
        _id: user._id,
        email: (user.email ?? '').toString(),
        phone: user.phone?.toString(),
        roles: user.roles ?? [],
        firmId: user.firmId?.toString(),
      },
      ipAddress,
    );
  }

  async login(dto: LoginDto, metadata: { ipAddress?: string; userAgent?: string }) {
    const identifier = (dto.identifier ?? dto.email ?? dto.phone ?? '').trim();
    if (!identifier) {
      throw new BadRequestException('Email or phone is required');
    }

    const user = await this.usersService.findByIdentifier(identifier);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return this.createTokens(
      {
        _id: user._id,
        email: (user.email ?? '').toString(),
        phone: user.phone?.toString(),
        roles: user.roles ?? [],
        firmId: user.firmId?.toString(),
      },
      metadata.ipAddress,
      metadata.userAgent,
    );
  }

  async forgotPassword(
    dto: ForgotPasswordDto,
    metadata: { ipAddress?: string; userAgent?: string },
  ) {
    const identifier = (dto.identifier ?? dto.email ?? dto.phone ?? '').trim();
    if (!identifier) {
      throw new BadRequestException('Email or phone is required');
    }

    const user = await this.usersService.findByIdentifier(identifier);
    const genericMessage =
      'If the account exists, a reset code has been generated.';

    if (!user || !user.isActive) {
      return {
        success: true,
        message: genericMessage,
      };
    }

    const identifierType: 'email' | 'phone' = identifier.includes('@')
      ? 'email'
      : 'phone';
    const identifierValue = this.normalizeIdentifierValue(
      identifier,
      identifierType,
    );

    const now = new Date();
    await this.passwordResetChallengeModel.updateMany(
      {
        userId: user._id,
        usedAt: null,
        expiresAt: { $gt: now },
      },
      { $set: { usedAt: now } },
    );

    const code = this.generateResetCode();
    const ttlMinutes = Math.max(
      5,
      Number(this.configService.get<number>('auth.passwordResetCodeTtlMinutes') ?? 15),
    );
    const expiresAt = new Date(now.getTime() + ttlMinutes * 60 * 1000);

    const challenge = await this.passwordResetChallengeModel.create({
      userId: user._id,
      identifierType,
      identifierValue,
      codeHash: this.hashToken(code),
      expiresAt,
      attempts: 0,
      maxAttempts: 5,
      ipAddress: metadata.ipAddress,
      userAgent: metadata.userAgent,
    });

    await this.auditService.record({
      action: 'auth.password-reset.request',
      entity: 'users',
      entityId: user._id?.toString(),
      ipAddress: metadata.ipAddress,
      payload: {
        identifierType,
      },
    });

    const response: Record<string, unknown> = {
      success: true,
      message: genericMessage,
      challengeId: challenge._id.toString(),
      expiresAt: challenge.expiresAt,
      delivery: identifierType,
    };

    const exposeCode = this.configService.get<boolean>('auth.passwordResetExposeCode');
    if (exposeCode) {
      response.resetCode = code;
    }

    return response;
  }

  async resetPassword(
    dto: ResetPasswordDto,
    metadata: { ipAddress?: string; userAgent?: string },
  ) {
    const challenge = await this.passwordResetChallengeModel.findById(
      dto.challengeId,
    );

    if (!challenge) {
      throw new UnauthorizedException('Invalid or expired reset code');
    }

    const now = new Date();
    if (challenge.usedAt || challenge.expiresAt.getTime() <= now.getTime()) {
      throw new UnauthorizedException('Invalid or expired reset code');
    }

    if (challenge.attempts >= challenge.maxAttempts) {
      challenge.usedAt = now;
      await challenge.save();
      throw new UnauthorizedException('Invalid or expired reset code');
    }

    const providedHash = this.hashToken(dto.code.trim());
    if (providedHash !== challenge.codeHash) {
      challenge.attempts += 1;
      if (challenge.attempts >= challenge.maxAttempts) {
        challenge.usedAt = new Date();
      }
      await challenge.save();
      throw new UnauthorizedException('Invalid or expired reset code');
    }

    await this.usersService.updatePassword(challenge.userId.toString(), dto.newPassword);
    challenge.usedAt = new Date();
    await challenge.save();

    await this.refreshTokenModel.updateMany(
      {
        userId: challenge.userId,
        revoked: false,
      },
      { $set: { revoked: true } },
    );

    await this.auditService.record({
      action: 'auth.password-reset.confirm',
      entity: 'users',
      entityId: challenge.userId.toString(),
      ipAddress: metadata.ipAddress,
      payload: {
        identifierType: challenge.identifierType,
      },
    });

    return {
      success: true,
      message: 'Password reset completed successfully',
    };
  }

  async me(user: JwtUserPayload) {
    return this.usersService.findById(user.sub);
  }

  async refresh(dto: RefreshDto, ipAddress?: string) {
    const payload = this.verifyRefreshToken(dto.refreshToken);
    const hashed = this.hashToken(dto.refreshToken);

    const stored = await this.refreshTokenModel.findOne({
      userId: new Types.ObjectId(payload.sub),
      tokenHash: hashed,
      revoked: false,
      expiresAt: { $gt: new Date() },
    });

    if (!stored) {
      throw new UnauthorizedException('Refresh token invalid');
    }

    stored.revoked = true;
    await stored.save();

    const user = await this.usersService.findById(payload.sub);
    return this.createTokens(
      {
        _id: (user as any)._id,
        email: ((user as any).email ?? '').toString(),
        phone: (user as any).phone?.toString(),
        roles: (user as any).roles ?? [],
        firmId: (user as any).firmId?.toString(),
      },
      ipAddress,
    );
  }

  async logout(dto: RefreshDto) {
    const payload = this.verifyRefreshToken(dto.refreshToken);
    const hashed = this.hashToken(dto.refreshToken);
    await this.refreshTokenModel.updateOne(
      { userId: new Types.ObjectId(payload.sub), tokenHash: hashed },
      { $set: { revoked: true } },
    );
    return { success: true };
  }

  private async createTokens(
    user: {
      _id: any;
      email: string;
      phone?: string;
      roles: string[];
      firmId?: string | null;
    },
    ipAddress?: string,
    userAgent?: string,
  ) {
    const payload: JwtUserPayload = {
      sub: user._id.toString(),
      email: user.email,
      phone: user.phone,
      roles: user.roles,
      firmId: user.firmId,
    };

    const accessToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('jwt.accessSecret'),
      expiresIn: this.configService.get<string>('jwt.accessTtl') as any,
    });

    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('jwt.refreshSecret'),
      expiresIn: this.configService.get<string>('jwt.refreshTtl') as any,
    });

    const tokenHash = this.hashToken(refreshToken);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await this.refreshTokenModel.create({
      userId: new Types.ObjectId(user._id.toString()),
      tokenHash,
      expiresAt,
      ipAddress,
      userAgent,
    });

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.configService.get<string>('jwt.accessTtl'),
      user: payload,
    };
  }

  private verifyRefreshToken(token: string): JwtUserPayload {
    try {
      return this.jwtService.verify<JwtUserPayload>(token, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token expired or invalid');
    }
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private generateResetCode(): string {
    return randomInt(100000, 999999).toString();
  }

  private normalizeIdentifierValue(
    identifier: string,
    type: 'email' | 'phone',
  ): string {
    if (type === 'email') {
      return identifier.toLowerCase().trim();
    }

    return identifier
      .trim()
      .replace(/\s+/g, '')
      .replace(/-/g, '')
      .replace(/\(/g, '')
      .replace(/\)/g, '');
  }
}
