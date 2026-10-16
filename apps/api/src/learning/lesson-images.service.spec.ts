import { mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { mkdtemp, access, rm } from 'node:fs/promises';
import { LessonImagesService } from './lesson-images.service';

describe('LessonImagesService media lifecycle', () => {
  const lessonId = '11111111-1111-4111-8111-111111111111';
  let root: string;
  let previousUploadsDir: string | undefined;

  beforeEach(async () => {
    root = await mkdtemp(join(tmpdir(), 'anzen-lesson-images-'));
    previousUploadsDir = process.env.UPLOADS_DIR;
    process.env.UPLOADS_DIR = root;
  });

  afterEach(async () => {
    if (previousUploadsDir === undefined) delete process.env.UPLOADS_DIR;
    else process.env.UPLOADS_DIR = previousUploadsDir;
    await rm(root, { recursive: true, force: true });
  });

  it('removes both knowledge and exercise media with the lesson', async () => {
    const lessonRoot = join(root, 'Kiến thức', lessonId);
    await mkdir(join(lessonRoot, 'Bài học'), { recursive: true });
    await mkdir(join(lessonRoot, 'Bài tập'), { recursive: true });
    await writeFile(join(lessonRoot, 'Bài học', 'knowledge.webp'), 'image');
    await writeFile(join(lessonRoot, 'Bài tập', 'exercise.webp'), 'image');

    await new LessonImagesService().removeLesson(lessonId);

    await expect(access(lessonRoot)).rejects.toThrow();
  });

  it('cleans Drive and media records before removing the local directory', async () => {
    const removeLessonMedia = jest.fn().mockResolvedValue({ deleted: 3 });
    const lessonRoot = join(root, 'Kiến thức', lessonId);
    await mkdir(lessonRoot, { recursive: true });

    await new LessonImagesService({ removeLessonMedia } as never).removeLesson(
      lessonId,
    );

    expect(removeLessonMedia).toHaveBeenCalledWith(lessonId);
    await expect(access(lessonRoot)).rejects.toThrow();
  });
});
