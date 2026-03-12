import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { QueueService } from './queue.service';

@Module({
  imports: [ConfigModule],
  providers: [QueueService, ConfigService],
  exports: [QueueService],
})
export class QueueModule {}
