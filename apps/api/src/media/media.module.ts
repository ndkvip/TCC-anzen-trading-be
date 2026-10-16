import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MediaAsset } from './media-asset.entity';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { GoogleDriveService } from './google-drive.service';
@Module({
  imports: [TypeOrmModule.forFeature([MediaAsset])],
  controllers: [MediaController],
  providers: [MediaService, GoogleDriveService],
  exports: [MediaService, GoogleDriveService],
})
export class MediaModule {}
