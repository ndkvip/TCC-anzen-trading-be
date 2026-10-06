import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum JournalMode {
  INTRA_DAY = 'INTRA_DAY',
  SWING = 'SWING',
}
export enum TradeDirection {
  LONG = 'LONG',
  SHORT = 'SHORT',
}

@Entity({ name: 'trade_journals' })
@Index(['userId', 'mode', 'tradeDate'])
export class TradeJournal {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'user_id', type: 'uuid' }) userId!: string;
  @Column({ type: 'enum', enum: JournalMode }) mode!: JournalMode;
  @Column({ name: 'trade_date', type: 'date', nullable: true }) tradeDate!:
    string | null;
  @Column() symbol!: string;
  @Column({ type: 'enum', enum: TradeDirection }) direction!: TradeDirection;
  @Column({ name: 'entry_at', type: 'timestamptz', nullable: true })
  entryAt!: Date | null;
  @Column({ name: 'holding_hours', type: 'double precision', nullable: true })
  holdingHours!: number | null;
  @Column({ type: 'varchar', default: 'Xử lý lệnh' }) management!: string;
  @Column({ name: 'risk_reward', type: 'double precision', nullable: true })
  riskReward!: number | null;
  @Column({ type: 'double precision', nullable: true }) pnl!: number | null;
  @Column({ name: 'timeframe_pair', type: 'varchar', nullable: true })
  timeframePair!: string | null;
  @Column({ name: 'price_movement', type: 'varchar', nullable: true })
  priceMovement!: string | null;
  @Column({
    name: 'process_image_urls',
    type: 'jsonb',
    default: () => "'[]'::jsonb",
  })
  processImageUrls!: string[];
  @Column({ type: 'text', nullable: true }) idea!: string | null;
  @Column({ type: 'text', nullable: true }) execution!: string | null;
  @Column({ type: 'text', nullable: true }) result!: string | null;
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
