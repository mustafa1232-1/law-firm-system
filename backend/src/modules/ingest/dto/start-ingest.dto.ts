import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class StartIngestDto {
  @ApiProperty()
  @IsString()
  source: string;

  @ApiProperty()
  @IsString()
  sourceType: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  rawText?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  filePath?: string;
}
