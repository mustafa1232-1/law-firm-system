import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsDateString, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateCaseDto {
  @ApiProperty()
  @IsString()
  caseNumber: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  internalReference?: string;

  @ApiProperty()
  @IsString()
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  court?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  governorate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  clientId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  summary?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  facts?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  claims?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  evidenceList?: string[];

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  lawyerIds?: string[];

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  @IsDateString({}, { each: true })
  hearingDates?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  fees?: number;
}
