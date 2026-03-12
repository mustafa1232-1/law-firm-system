import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class CreateDecisionDto {
  @ApiProperty()
  @IsString()
  source: string;

  @ApiProperty()
  @IsString()
  sourceType: string;

  @ApiProperty()
  @IsString()
  courtName: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtLevel?: string;

  @ApiProperty()
  @IsString()
  decisionNumber: string;

  @ApiProperty()
  @IsDateString()
  decisionDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  legalDomain?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  summary?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  fullText?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  legalKeywords?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  outcome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  confidenceScore?: number;
}
