import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JournalController } from './journal.controller';
import { JournalService } from './journal.service';
import { TradeJournal } from './trade-journal.entity';
@Module({
  imports: [TypeOrmModule.forFeature([TradeJournal])],
  controllers: [JournalController],
  providers: [JournalService],
  exports: [JournalService],
})
export class JournalModule {}
