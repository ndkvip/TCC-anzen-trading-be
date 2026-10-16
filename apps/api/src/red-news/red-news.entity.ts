import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'red_news' })
export class RedNews {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  title!: string;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ type: 'varchar', nullable: true })
  currency!: string | null;

  @Column({ type: 'varchar', default: 'HIGH' })
  impact!: 'LOW' | 'MEDIUM' | 'HIGH';

  @Column({ name: 'release_at', type: 'timestamptz' })
  releaseAt!: Date;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Index()
  @Column({ type: 'varchar', default: 'MANUAL' })
  source!: 'MANUAL' | 'FOREX_FACTORY_CALENDAR';

  @Index({ unique: true })
  @Column({ name: 'source_key', type: 'varchar', nullable: true })
  sourceKey!: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
