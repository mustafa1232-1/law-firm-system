import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsDateString, IsOptional, IsString } from 'class-validator';

export class CreateHearingDto {
  @ApiProperty()
  @IsString()
  caseId: string;

  @ApiProperty()
  @IsDateString()
  hearingDate: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  court?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtGovernorate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtCity?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtDistrict?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtArea?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  courtLocationDescription?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  room?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  judge?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  requiredDocuments?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  outcome?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  nextAction?: string;
}
