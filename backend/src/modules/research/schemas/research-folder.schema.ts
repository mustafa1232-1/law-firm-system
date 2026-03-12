import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ResearchFolderDocument = HydratedDocument<ResearchFolder>;

@Schema({ timestamps: true, versionKey: false, collection: 'research_folders' })
export class ResearchFolder {
  @Prop({ type: Types.ObjectId, ref: 'User', required: false })
  userId?: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: false })
  description?: string;

  @Prop({ type: [String], default: [] })
  tags: string[];
}

export const ResearchFolderSchema = SchemaFactory.createForClass(ResearchFolder);
