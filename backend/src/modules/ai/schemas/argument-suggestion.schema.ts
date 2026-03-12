import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ArgumentSuggestionDocument = HydratedDocument<ArgumentSuggestion>;

@Schema({ timestamps: true, versionKey: false, collection: 'argument_suggestions' })
export class ArgumentSuggestion {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  argumentType: 'primary' | 'counter' | 'procedural';

  @Prop({ required: true })
  content: string;

  @Prop({ type: [String], default: [] })
  authorityIds: string[];

  @Prop({ default: 0.5 })
  confidenceScore: number;
}

export const ArgumentSuggestionSchema = SchemaFactory.createForClass(ArgumentSuggestion);
