import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
@Entity({ name: 'daily_checkins' })
@Index(['userId', 'checkinDate'], { unique: true })
export class DailyCheckin {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ name: 'user_id', type: 'uuid' }) userId!: string;
  @Column({ name: 'checkin_date', type: 'date' }) checkinDate!: string;
  @Column({ type: 'jsonb' }) scores!: number[];
  @Column({ name: 'total_score', type: 'double precision' })
  totalScore!: number;
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
