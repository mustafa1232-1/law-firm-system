import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type PasswordResetChallengeDocument =
  HydratedDocument<PasswordResetChallenge>;

@Schema({
  timestamps: true,
  versionKey: false,
  collection: 'password_reset_challenges',
})
export class PasswordResetChallenge {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true, enum: ['email', 'phone'] })
  identifierType: 'email' | 'phone';

  @Prop({ required: true, trim: true })
  identifierValue: string;

  @Prop({ required: true })
  codeHash: string;

  @Prop({ required: true })
  expiresAt: Date;

  @Prop({ required: false })
  usedAt?: Date;

  @Prop({ default: 0 })
  attempts: number;

  @Prop({ default: 5 })
  maxAttempts: number;

  @Prop({ required: false })
  ipAddress?: string;

  @Prop({ required: false })
  userAgent?: string;
}

export const PasswordResetChallengeSchema = SchemaFactory.createForClass(
  PasswordResetChallenge,
);

PasswordResetChallengeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
PasswordResetChallengeSchema.index({ userId: 1, usedAt: 1, expiresAt: 1 });

