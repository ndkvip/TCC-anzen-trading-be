import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { MediaModule } from '../media/media.module';
import { FeaturedTradeController } from './featured-trade.controller';
import { FeaturedTrade } from './featured-trade.entity';
import { FeaturedTradeService } from './featured-trade.service';
import { FeaturedTradeImagesService } from './featured-trade-images.service';
import { HomePostsController } from './home-posts.controller';

@Module({
  imports: [TypeOrmModule.forFeature([FeaturedTrade]), AuthModule, MediaModule],
  controllers: [FeaturedTradeController, HomePostsController],
  providers: [FeaturedTradeService, FeaturedTradeImagesService],
})
export class FeaturedTradesModule {}
