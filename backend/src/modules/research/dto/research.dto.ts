import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class SearchResearchDto {
  @ApiProperty()
  @IsString()
  q: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  type?: 'constitution' | 'law' | 'decision';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  court?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  legalDomain?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  exactPhrase?: boolean;
}

export class CreateResearchFolderDto {
  @ApiProperty()
  @IsString()
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;
}

export class SaveAuthorityDto {
  @ApiProperty()
  @IsString()
  authorityType: 'constitution' | 'law' | 'decision' | 'note';

  @ApiProperty()
  @IsString()
  authorityId: string;

  @ApiProperty()
  @IsString()
  citation: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  caseId?: string;
}
