import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
} from 'class-validator';

export class CaseAnalysisDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;

  @ApiProperty()
  @IsString()
  description: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseTypeHint?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  documentIds?: string[];
}

export class LegalResearchDto {
  @ApiProperty()
  @IsString()
  query: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sessionId?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  documentIds?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  searchConstitution?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  searchLaws?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  searchDecisions?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  searchMyKnowledgeOnly?: boolean;
}

export class ArgumentBuilderDto {
  @ApiProperty()
  @IsString()
  narrative: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;
}

export class MemoDraftDto {
  @ApiProperty()
  @IsString()
  topic: string;

  @ApiProperty()
  @IsString()
  facts: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;
}

export class SaveAiAnalysisDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sessionId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;

  @ApiProperty({ description: 'analysis type, ex: legal-research, case-analysis' })
  @IsString()
  analysisType: string;

  @ApiProperty()
  @IsString()
  inputText: string;

  @ApiProperty({ description: 'raw analysis payload to persist' })
  @IsObject()
  output: Record<string, unknown>;

  @ApiPropertyOptional({ isArray: true, description: 'citations payload' })
  @IsOptional()
  @IsArray()
  citations?: Array<Record<string, unknown>>;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  confidenceScore?: number;
}

export class AttachAiAnalysisToCaseDto {
  @ApiProperty()
  @IsString()
  caseId: string;
}
