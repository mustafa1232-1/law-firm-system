import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class AnalyzeDocumentDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  customPrompt?: string;
}
