import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'featured_trades' })
@Unique(['weekStart'])
export class FeaturedTrade {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'week_start', type: 'date' }) weekStart!: string;
  @Column({ name: 'image_urls', type: 'jsonb', default: () => "'[]'::jsonb" })
  imageUrls!: string[];
  @Column({ name: 'is_active', default: true }) isActive!: boolean;
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
