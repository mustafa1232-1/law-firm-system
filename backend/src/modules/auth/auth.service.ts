import {
  Injectable,
  UnauthorizedException,
  ConflictException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { createHash } from 'crypto';
import { AuditService } from '../audit/audit.service';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';
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
  ) {}

  async register(dto: RegisterDto, ipAddress?: string) {
    const existing = await this.usersService.findByEmail(dto.email);
    if (existing) {
      throw new ConflictException('Email already used');
    }

    await this.usersService.create(
      {
        ...dto,
        password: dto.password,
      },
      undefined,
    );
    const user = await this.usersService.findByEmail(dto.email);
    if (!user) {
      throw new UnauthorizedException('Unable to complete registration');
    }

    await this.auditService.record({
      action: 'auth.register',
      entity: 'users',
      entityId: user._id?.toString(),
      ipAddress,
      payload: { email: dto.email },
    });

    return this.createTokens(
      {
        _id: user._id,
        email: user.email,
        roles: user.roles ?? [],
        firmId: user.firmId?.toString(),
      },
      ipAddress,
    );
  }

  async login(dto: LoginDto, metadata: { ipAddress?: string; userAgent?: string }) {
    const user = await this.usersService.findByEmail(dto.email);
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
        email: user.email,
        roles: user.roles ?? [],
        firmId: user.firmId?.toString(),
      },
      metadata.ipAddress,
      metadata.userAgent,
    );
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
        email: (user as any).email,
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
    user: { _id: any; email: string; roles: string[]; firmId?: string | null },
    ipAddress?: string,
    userAgent?: string,
  ) {
    const payload: JwtUserPayload = {
      sub: user._id.toString(),
      email: user.email,
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
}
