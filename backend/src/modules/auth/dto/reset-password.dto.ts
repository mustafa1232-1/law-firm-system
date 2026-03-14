import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({ description: 'Password reset challenge ID' })
  @IsString()
  challengeId: string;

  @ApiProperty({ description: 'Reset code received via email/phone' })
  @IsString()
  code: string;

  @ApiProperty({ description: 'New password', minLength: 8 })
  @IsString()
  @MinLength(8)
  newPassword: string;
}

