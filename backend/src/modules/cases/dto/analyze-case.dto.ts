import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class AnalyzeCaseDto {
  @ApiProperty({ description: 'Optional custom context for AI analysis', required: false })
  @IsOptional()
  @IsString()
  context?: string;
}
