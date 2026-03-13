import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class CreateCaseClientDto {
  @ApiProperty()
  @IsString()
  fullName: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  companyName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  address?: string;
}

export class CreateCaseEvidenceEntryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  documentId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  attachmentName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;
}

export class CaseInstallmentDto {
  @ApiProperty()
  @IsDateString()
  dueDate: string;

  @ApiProperty()
  @IsNumber()
  amount: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  label?: string;
}

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
  courtId?: string;

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
  oppositeParty?: string;

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

  @ApiPropertyOptional({ type: [CreateCaseEvidenceEntryDto] })
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CreateCaseEvidenceEntryDto)
  evidenceEntries?: CreateCaseEvidenceEntryDto[];

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

  @ApiPropertyOptional({ description: 'Case contract amount in IQD' })
  @IsOptional()
  @IsNumber()
  contractAmount?: number;

  @ApiPropertyOptional({ description: 'Contract signing date' })
  @IsOptional()
  @IsDateString()
  contractDate?: string;

  @ApiPropertyOptional({ description: 'Initial payment to register immediately' })
  @IsOptional()
  @IsNumber()
  initialPayment?: number;

  @ApiPropertyOptional({ description: 'Second installment amount' })
  @IsOptional()
  @IsNumber()
  secondPaymentAmount?: number;

  @ApiPropertyOptional({ description: 'Second installment due date' })
  @IsOptional()
  @IsDateString()
  secondPaymentDueDate?: string;

  @ApiPropertyOptional({ type: [CaseInstallmentDto] })
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CaseInstallmentDto)
  additionalInstallments?: CaseInstallmentDto[];

  @ApiPropertyOptional({ type: CreateCaseClientDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => CreateCaseClientDto)
  newClient?: CreateCaseClientDto;
}
