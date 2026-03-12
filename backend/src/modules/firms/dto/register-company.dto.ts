import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { CreateFirmDto } from './create-firm.dto';

export class RegisterCompanyDto extends CreateFirmDto {
  @ApiProperty()
  @IsString()
  adminFullName: string;

  @ApiProperty()
  @IsEmail()
  adminEmail: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adminPhone?: string;

  @ApiProperty()
  @IsString()
  @MinLength(8)
  adminPassword: string;
}
