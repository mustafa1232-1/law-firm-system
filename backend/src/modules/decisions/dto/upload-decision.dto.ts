import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
} from 'class-validator';

export class UploadDecisionDto {
  @ApiProperty()
  @IsString()
  courtName: string;

  @ApiPropertyOptional({ enum: ['appellate', 'cassation'] })
  @IsOptional()
  @IsIn(['appellate', 'cassation'])
  courtLevel?: 'appellate' | 'cassation';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  governorate?: string;

  @ApiProperty()
  @IsString()
  decisionNumber: string;

  @ApiProperty()
  @IsDateString()
  decisionDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  publicationDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  chamber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  source?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sourceType?: string;

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

  @ApiPropertyOptional({
    description: 'JSON array string or comma-separated list',
  })
  @IsOptional()
  @IsString()
  tags?: string;

  @ApiPropertyOptional({
    description: 'JSON array string or comma-separated list',
  })
  @IsOptional()
  @IsString()
  legalKeywords?: string;

  @ApiPropertyOptional({
    description: 'JSON array string or comma-separated list',
  })
  @IsOptional()
  @IsString()
  legalArticleReferences?: string;

  @ApiPropertyOptional({
    description: 'JSON array string or comma-separated list',
  })
  @IsOptional()
  @IsString()
  constitutionalReferences?: string;
}
