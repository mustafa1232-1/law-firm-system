import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type AiSessionDocument = HydratedDocument<AiSession>;

@Schema({ timestamps: true, versionKey: false, collection: 'ai_sessions' })
export class AiSession {
  @Prop({ type: Types.ObjectId, ref: 'User', required: false })
  userId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ default: 'active' })
  status: 'active' | 'closed';

  @Prop({ type: Object, default: {} })
  context: Record<string, unknown>;
}

export const AiSessionSchema = SchemaFactory.createForClass(AiSession);
