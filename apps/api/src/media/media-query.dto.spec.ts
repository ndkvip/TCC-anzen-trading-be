import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { MediaContextType } from './media-context';
import { MediaQueryDto } from './media-query.dto';

describe('MediaQueryDto', () => {
  it('transforms pagination values and accepts supported filters', async () => {
    const dto = plainToInstance(MediaQueryDto, {
      ownerId: 'd2719d6b-4d5c-4c2a-9a41-2f6e390c11f4',
      contextType: MediaContextType.JOURNAL,
      search: 'student_1',
      page: '2',
      pageSize: '50',
    });

    expect(await validate(dto)).toHaveLength(0);
    expect(dto.page).toBe(2);
    expect(dto.pageSize).toBe(50);
  });

  it('rejects malformed UUIDs, contexts, and unsafe page sizes', async () => {
    const dto = plainToInstance(MediaQueryDto, {
      ownerId: 'not-a-uuid',
      contextType: 'UNKNOWN',
      page: '0',
      pageSize: '101',
    });

    expect((await validate(dto)).length).toBeGreaterThan(0);
  });
});
