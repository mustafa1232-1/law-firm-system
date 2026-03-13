import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CourtsController } from './courts.controller';
import { CourtsService } from './courts.service';
import { Court, CourtSchema } from './schemas/court.schema';

@Module({
  imports: [MongooseModule.forFeature([{ name: Court.name, schema: CourtSchema }])],
  controllers: [CourtsController],
  providers: [CourtsService],
  exports: [CourtsService],
})
export class CourtsModule {}
