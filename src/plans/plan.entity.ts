import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
export enum PlanScope {
  MONTH = 'MONTH',
  WEEK = 'WEEK',
  DAY = 'DAY',
}
@Entity({ name: 'trading_plans' })
@Index(['userId', 'scope', 'periodKey'], { unique: true })
export class TradingPlan {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'user_id', type: 'uuid' }) userId!: string;
  @Column({ type: 'enum', enum: PlanScope }) scope!: PlanScope;
  @Column({ name: 'period_key' }) periodKey!: string;
  @Column() title!: string;
  @Column({
    name: 'content_delta',
    type: 'jsonb',
    default: () => "'[]'::jsonb",
  })
  contentDelta!: Record<string, unknown>[];
  @Column({
    name: 'timeframe_pairs',
    type: 'jsonb',
    default: () => "'[]'::jsonb",
  })
  timeframePairs!: string[];
  @Column({ name: 'inherited_plan_id', type: 'uuid', nullable: true })
  inheritedPlanId!: string | null;
  @Column({ name: 'image_urls', type: 'jsonb', default: () => "'[]'::jsonb" })
  imageUrls!: string[];
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
