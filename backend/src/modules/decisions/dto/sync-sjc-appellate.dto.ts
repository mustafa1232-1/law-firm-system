import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export class SyncSjcAppellateDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  startId?: number = 1;

  @ApiPropertyOptional({ default: 12000 })
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(120000)
  endId?: number = 12000;

  @ApiPropertyOptional({ default: 20, description: 'Parallel fetch workers' })
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(50)
  concurrency?: number = 20;

  @ApiPropertyOptional({ default: 5000, description: 'Maximum decisions to collect per run' })
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(10)
  @Max(30000)
  maxDecisions?: number = 5000;

  @ApiPropertyOptional({
    enum: ['appellate', 'all'],
    default: 'all',
    description: 'When appellate, keeps rows that look appellate/cassation-oriented.',
  })
  @IsOptional()
  @IsIn(['appellate', 'all'])
  mode?: 'appellate' | 'all' = 'all';

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  dryRun?: boolean = false;
}
