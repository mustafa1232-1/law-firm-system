import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
import { SystemRole } from 'src/common/constants/system.constants';

export type UserDocument = HydratedDocument<User>;

@Schema({ timestamps: true, versionKey: false, collection: 'users' })
export class User {
  @Prop({ type: Types.ObjectId, ref: 'Firm', required: false })
  firmId?: Types.ObjectId;

  @Prop({ required: true })
  fullName: string;

  @Prop({
    required: false,
    unique: true,
    sparse: true,
    lowercase: true,
    trim: true,
  })
  email?: string;

  @Prop({ required: false, unique: true, sparse: true, trim: true })
  phone?: string;

  @Prop({ required: true })
  passwordHash: string;

  @Prop({ type: [String], default: [SystemRole.LAWYER] })
  roles: string[];

  @Prop({ type: [String], default: [] })
  permissions: string[];

  @Prop({ default: 'ar-IQ' })
  locale: string;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ required: false })
  title?: string;
}

export const UserSchema = SchemaFactory.createForClass(User);
