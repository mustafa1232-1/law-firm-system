import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateDocumentDto {
  @ApiProperty()
  @IsString()
  title: string;

  @ApiProperty()
  @IsString()
  originalName: string;

  @ApiProperty()
  @IsString()
  mimeType: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  extractedText?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  sizeBytes?: number;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  tags?: string[];
}
