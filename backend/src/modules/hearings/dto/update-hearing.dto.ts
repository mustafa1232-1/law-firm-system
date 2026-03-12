import { PartialType } from '@nestjs/swagger';
import { CreateHearingDto } from './create-hearing.dto';

export class UpdateHearingDto extends PartialType(CreateHearingDto) {}
