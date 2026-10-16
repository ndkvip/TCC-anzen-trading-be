import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { MediaContextType } from './media-context';

@Entity({ name: 'media_assets' })
@Index(['ownerId', 'createdAt'])
@Index(['contextType', 'contextId'])
export class MediaAsset {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'owner_id', type: 'uuid' }) ownerId!: string;
  @Column({ name: 'drive_file_id', type: 'varchar', nullable: true })
  driveFileId!: string | null;
  @Column({ name: 'drive_folder_id', type: 'varchar', nullable: true })
  driveFolderId!: string | null;
  @Column({ name: 'folder_path', type: 'text' }) folderPath!: string;
  @Column() name!: string;
  @Column({ name: 'mime_type' }) mimeType!: string;
  @Column({ name: 'remote_url', type: 'text' }) remoteUrl!: string;
  @Column({ name: 'thumbnail_url', type: 'text', nullable: true })
  thumbnailUrl!: string | null;
  @Column({ name: 'local_reference', type: 'text', nullable: true })
  localReference!: string | null;
  @Column({ name: 'size_bytes', type: 'bigint', default: 0 })
  sizeBytes!: string;
  @Column({
    name: 'context_type',
    type: 'varchar',
    default: MediaContextType.GENERAL,
  })
  contextType!: MediaContextType;
  @Column({ name: 'context_id', type: 'varchar', nullable: true })
  contextId!: string | null;
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
}
