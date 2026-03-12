import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class IngestDecisionDto {
  @ApiProperty({ description: 'Source URL or source identifier' })
  @IsString()
  source: string;

  @ApiProperty()
  @IsString()
  sourceType: string;

  @ApiPropertyOptional({ description: 'Raw text if available' })
  @IsOptional()
  @IsString()
  rawText?: string;

  @ApiPropertyOptional({ description: 'Binary file path or storage key' })
  @IsOptional()
  @IsString()
  filePath?: string;
}
