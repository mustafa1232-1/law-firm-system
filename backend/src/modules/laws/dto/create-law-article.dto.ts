import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsArray, IsOptional, IsString } from 'class-validator';

export class CreateLawArticleDto {
  @ApiProperty()
  @IsString()
  lawId: string;

  @ApiProperty()
  @IsString()
  articleNumber: string;

  @ApiProperty()
  @IsString()
  text: string;

  @ApiPropertyOptional({ isArray: true })
  @IsOptional()
  @IsArray()
  keywords?: string[];
}
