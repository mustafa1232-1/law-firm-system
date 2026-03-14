import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class LoginDto {
  @ApiPropertyOptional({
    description: 'Email or phone number',
    example: 'mustafa@1.net',
  })
  @IsOptional()
  @IsString()
  identifier?: string;

  @ApiPropertyOptional({
    description: 'Email (legacy compatibility)',
    example: 'mustafa@1.net',
  })
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional({
    description: 'Phone number (legacy compatibility)',
    example: '+9647700000000',
  })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiProperty()
  @IsString()
  password: string;
}
