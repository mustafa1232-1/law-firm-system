import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class UploadDocumentDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  originalName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  mimeType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  extractedText?: string;

  @ApiPropertyOptional({
    description: 'JSON array string or comma-separated list, e.g. ["evidence","contract"]',
  })
  @IsOptional()
  @IsString()
  tags?: string;
}
