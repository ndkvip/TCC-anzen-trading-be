import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { RedNewsController } from './red-news.controller';
import { RedNews } from './red-news.entity';
import { RedNewsService } from './red-news.service';

@Module({
  imports: [TypeOrmModule.forFeature([RedNews]), AuthModule],
  controllers: [RedNewsController],
  providers: [RedNewsService],
})
export class RedNewsModule {}
