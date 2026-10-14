import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class AdminService {
  constructor(private readonly database: DataSource) {}

  async dashboard(now = new Date()) {
    const [summary, activity] = await Promise.all([
      this.database.query(`
        WITH students AS (SELECT * FROM users WHERE role = 'STUDENT'),
        started AS (
          SELECT p.progress FROM lesson_progress p
          JOIN students u ON u.id = p.user_id
          JOIN lessons l ON l.id = p.lesson_id AND l.is_published
          WHERE p.progress > 0
        )
        SELECT
          (SELECT count(*) FROM students) AS "studentCount",
          (SELECT count(*) FROM lessons) AS "lessonCount",
          (SELECT count(*) FROM started) AS "startedLessons",
          (SELECT count(*) FROM started WHERE progress >= 1) AS "completedLessons",
          (SELECT count(*) FROM lessons WHERE NOT is_published) AS "draftLessons",
          (SELECT count(*) FROM lessons WHERE NOT is_published AND
            (jsonb_array_length(knowledge_cards) = 0 OR jsonb_array_length(questions) = 0)) AS "incompleteLessons",
          (SELECT count(*) FROM students WHERE NOT is_active) AS "inactiveStudents",
          (SELECT count(*) FROM students WHERE NOT email_verified) AS "unverifiedStudents"
      `),
      this.database.query(
        `
        WITH bounds AS (
          SELECT
            ($1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 6 AS first_day,
            ($1::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS last_day
        ), days AS (
          SELECT generate_series(
            bounds.first_day,
            bounds.last_day,
            interval '1 day'
          )::date AS day
          FROM bounds
        ), activity AS (
          SELECT user_id, updated_at FROM lesson_progress
          UNION ALL SELECT user_id, updated_at FROM trade_journals
          UNION ALL SELECT user_id, updated_at FROM trading_plans
          UNION ALL SELECT user_id, updated_at FROM daily_checkins
        ), daily AS (
          SELECT a.user_id,
            ((a.updated_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS day
          FROM activity a
          JOIN users u ON u.id = a.user_id AND u.role = 'STUDENT'
          CROSS JOIN bounds
          WHERE ((a.updated_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            BETWEEN bounds.first_day AND bounds.last_day
        )
        SELECT to_char(d.day, 'YYYY-MM-DD') AS date, count(DISTINCT a.user_id)::int AS "activeStudents"
        FROM days d LEFT JOIN daily a ON a.day = d.day
        GROUP BY d.day ORDER BY d.day
      `,
        [now.toISOString()],
      ),
    ]);
    const counts = Object.fromEntries(
      Object.entries(summary[0] ?? {}).map(([key, value]) => [
        key,
        Number(value),
      ]),
    );
    return {
      ...counts,
      completionRate: counts.startedLessons
        ? Math.round((counts.completedLessons / counts.startedLessons) * 1000) /
          10
        : 0,
      activity,
      timezone: 'Asia/Ho_Chi_Minh',
      generatedAt: now.toISOString(),
    };
  }
}
