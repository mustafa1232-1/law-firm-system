import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsInt, IsOptional, IsString } from 'class-validator';

export class CreateLawDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sourceName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  sourceUrl?: string;

  @ApiProperty()
  @IsString()
  title: string;

  @ApiProperty()
  @IsString()
  lawNumber: string;

  @ApiProperty()
  @IsInt()
  year: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  issuingBody?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  legalDomain?: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  keywords?: string[];
}
