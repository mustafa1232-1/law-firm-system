import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateLawArticleDto {
  @ApiProperty()
  @IsString()
  lawId: string;

  @ApiProperty()
  @IsString()
  articleNumber: string;

  @ApiPropertyOptional({
    description: 'Numeric order of the article for correct sorting (e.g. 12).',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  articleOrder?: number;

  @ApiProperty()
  @IsString()
  text: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  paragraphs?: string[];

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  keywords?: string[];
}
