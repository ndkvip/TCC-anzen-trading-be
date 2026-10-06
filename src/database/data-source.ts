import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { DailyCheckin } from '../checkins/checkin.entity';
import { TradeJournal } from '../journal/trade-journal.entity';
import { LessonProgress } from '../learning/lesson-progress.entity';
import { Lesson } from '../learning/lesson.entity';
import { MediaAsset } from '../media/media-asset.entity';
import { TradingPlan } from '../plans/plan.entity';
import { RedNews } from '../red-news/red-news.entity';
import { User } from '../users/user.entity';
import { InitialSchema20260831000000 } from './migrations/20260831000000-InitialSchema';
import { Phase3Schema20260902000000 } from './migrations/20260902000000-Phase3Schema';
import { UnpublishEmptyLessons20260929000000 } from './migrations/20260929000000-UnpublishEmptyLessons';
import { DriveMediaFolders20260903000000 } from './migrations/20260903000000-DriveMediaFolders';
import { FeaturedTrade } from '../featured-trades/featured-trade.entity';
import { FeaturedTrades20260912000000 } from './migrations/20260912000000-FeaturedTrades';
import { FeaturedTradeImages20260914000000 } from './migrations/20260914000000-FeaturedTradeImages';
import { RedNewsCalendarSync20260916000000 } from './migrations/20260916000000-RedNewsCalendarSync';

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
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
  ],
  ssl:
    process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: false } : false,
});
