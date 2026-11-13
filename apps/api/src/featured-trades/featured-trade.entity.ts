import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export type FeaturedTradeBlock = {
  type: 'text' | 'image';
  text?: string;
  imageUrl?: string;
};

export type ArticlePlacement = 'FEATURED_TRADE' | 'HOME_POST';

@Entity({ name: 'featured_trades' })
export class FeaturedTrade {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ type: 'varchar', default: 'FEATURED_TRADE' })
  placement!: ArticlePlacement;
  @Column({ name: 'week_start', type: 'date' }) weekStart!: string;
  @Column({ type: 'varchar', default: '' }) title!: string;
  @Column({ type: 'text', nullable: true }) summary!: string | null;
  @Column({ name: 'cover_image_url', type: 'text', nullable: true })
  coverImageUrl!: string | null;
  @Column({
    name: 'content_blocks',
    type: 'jsonb',
    default: () => "'[]'::jsonb",
  })
  contentBlocks!: FeaturedTradeBlock[];
  // Kept for compatibility with content created before the article editor.
  @Column({ name: 'image_urls', type: 'jsonb', default: () => "'[]'::jsonb" })
  imageUrls!: string[];
  @Column({ name: 'is_active', default: true }) isActive!: boolean;
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
