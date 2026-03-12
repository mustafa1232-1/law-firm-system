import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ReclassifyDecisionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  legalDomain?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reviewStatus?: 'pending' | 'approved' | 'rejected';
}
