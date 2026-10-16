import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum LessonTier {
  BASIC = 'BASIC',
  ADVANCED = 'ADVANCED',
}

@Entity({ name: 'lessons' })
export class Lesson {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ unique: true }) slug!: string;
  @Column() title!: string;
  @Column({ type: 'text', default: '' }) description!: string;
  @Column({ type: 'enum', enum: LessonTier }) tier!: LessonTier;
  @Column({ type: 'integer', default: 0 }) position!: number;
  @Column({ name: 'duration_minutes', type: 'integer', default: 10 })
  durationMinutes!: number;
  @Column({ name: 'is_published', default: true }) isPublished!: boolean;
  @Column({
    name: 'knowledge_cards',
    type: 'jsonb',
    default: () => "'[]'::jsonb",
  })
  knowledgeCards!: Record<string, unknown>[];
  @Column({ type: 'jsonb', default: () => "'[]'::jsonb" }) questions!: Record<
    string,
    unknown
  >[];
  @CreateDateColumn({ name: 'created_at' }) createdAt!: Date;
  @UpdateDateColumn({ name: 'updated_at' }) updatedAt!: Date;
}
