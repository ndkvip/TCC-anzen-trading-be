import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { CheckinsModule } from './checkins/checkins.module';
import { DailyCheckin } from './checkins/checkin.entity';
import { InitialSchema20260831000000 } from './database/migrations/20260831000000-InitialSchema';
import { Phase3Schema20260902000000 } from './database/migrations/20260902000000-Phase3Schema';
import { UnpublishEmptyLessons20260929000000 } from './database/migrations/20260929000000-UnpublishEmptyLessons';
import { DriveMediaFolders20260903000000 } from './database/migrations/20260903000000-DriveMediaFolders';
import { FeaturedTrades20260912000000 } from './database/migrations/20260912000000-FeaturedTrades';
import { FeaturedTradeImages20260914000000 } from './database/migrations/20260914000000-FeaturedTradeImages';
import { RedNewsCalendarSync20260916000000 } from './database/migrations/20260916000000-RedNewsCalendarSync';
import { FeaturedTradeArticles20261007000000 } from './database/migrations/20261007000000-FeaturedTradeArticles';
import { HealthController } from './health/health.controller';
import { FeaturedTrade } from './featured-trades/featured-trade.entity';
import { FeaturedTradesModule } from './featured-trades/featured-trades.module';
import { JournalModule } from './journal/journal.module';
import { TradeJournal } from './journal/trade-journal.entity';
import { LearningModule } from './learning/learning.module';
import { LessonProgress } from './learning/lesson-progress.entity';
import { Lesson } from './learning/lesson.entity';
import { MediaAsset } from './media/media-asset.entity';
import { MediaModule } from './media/media.module';
import { TradingPlan } from './plans/plan.entity';
import { PlansModule } from './plans/plans.module';
import { RedNews } from './red-news/red-news.entity';
import { RedNewsModule } from './red-news/red-news.module';
import { User } from './users/user.entity';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.getOrThrow<string>('DATABASE_URL'),
        entities: [
          User,
          RedNews,
          Lesson,
          LessonProgress,
          TradeJournal,
          TradingPlan,
          DailyCheckin,
          MediaAsset,
          FeaturedTrade,
        ],
        migrations: [
          InitialSchema20260831000000,
          Phase3Schema20260902000000,
          UnpublishEmptyLessons20260929000000,
          DriveMediaFolders20260903000000,
          FeaturedTrades20260912000000,
          FeaturedTradeImages20260914000000,
          RedNewsCalendarSync20260916000000,
          FeaturedTradeArticles20261007000000,
        ],
        migrationsRun: config.get('DATABASE_MIGRATIONS_RUN', 'true') === 'true',
        synchronize: config.get('DATABASE_SYNCHRONIZE', 'false') === 'true',
        ssl:
          config.get('DATABASE_SSL', 'false') === 'true'
            ? { rejectUnauthorized: false }
            : false,
      }),
    }),
    UsersModule,
    AuthModule,
    RedNewsModule,
    LearningModule,
    JournalModule,
    PlansModule,
    CheckinsModule,
    MediaModule,
    FeaturedTradesModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
