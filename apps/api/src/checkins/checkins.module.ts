import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CheckinsController } from './checkins.controller';
import { CheckinsService } from './checkins.service';
import { DailyCheckin } from './checkin.entity';
@Module({
  imports: [TypeOrmModule.forFeature([DailyCheckin])],
  controllers: [CheckinsController],
  providers: [CheckinsService],
})
export class CheckinsModule {}
