import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type SavedAuthorityDocument = HydratedDocument<SavedAuthority>;

@Schema({ timestamps: true, versionKey: false, collection: 'saved_authorities' })
export class SavedAuthority {
  @Prop({ type: Types.ObjectId, ref: 'ResearchFolder', required: true })
  folderId: Types.ObjectId;

  @Prop({ required: true })
  authorityType: 'constitution' | 'law' | 'decision' | 'note';

  @Prop({ required: true })
  authorityId: string;

  @Prop({ required: true })
  citation: string;

  @Prop({ required: false })
  notes?: string;

  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;
}

export const SavedAuthoritySchema = SchemaFactory.createForClass(SavedAuthority);
