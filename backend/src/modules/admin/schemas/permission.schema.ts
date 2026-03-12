import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type PermissionDocument = HydratedDocument<PermissionEntity>;

@Schema({ timestamps: true, versionKey: false, collection: 'permissions' })
export class PermissionEntity {
  @Prop({ required: true, unique: true })
  key: string;

  @Prop({ required: true })
  name: string;

  @Prop({ required: false })
  description?: string;
}

export const PermissionSchema = SchemaFactory.createForClass(PermissionEntity);
