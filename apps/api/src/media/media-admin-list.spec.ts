import { ForbiddenException } from '@nestjs/common';
import type { AuthRequestUser } from '../auth/auth.types';
import { AccountTier, LearningTier, UserRole } from '../users/user.entity';
import { MediaContextType } from './media-context';
import { MediaQueryDto } from './media-query.dto';
import { MediaService } from './media.service';

const actor = (role: UserRole): AuthRequestUser => ({
  sub: 'admin-id',
  email: 'admin@anzen.test',
  name: 'Admin',
  role,
  accountTier: AccountTier.STANDARD,
  learningTier: LearningTier.BASIC,
  deviceId: 'device',
  tokenVersion: 0,
  type: 'access',
});

describe('MediaService admin library', () => {
  it('filters, escapes search wildcards, paginates, and adds safe owner metadata', async () => {
    const asset = {
      id: 'media-1',
      ownerId: 'student-1',
      driveFileId: 'drive-1',
      driveFolderId: 'folder-1',
      folderPath: 'Nhật ký giao dịch/student-1',
      name: 'chart.webp',
      mimeType: 'image/webp',
      remoteUrl: 'https://drive.test/chart.webp',
      thumbnailUrl: null,
      localReference: null,
      sizeBytes: '2048',
      contextType: MediaContextType.JOURNAL,
      contextId: 'student-1',
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
    };
    const builder: any = {
      leftJoin: jest.fn(() => builder),
      addSelect: jest.fn(() => builder),
      andWhere: jest.fn(() => builder),
      getCount: jest.fn().mockResolvedValue(1),
      orderBy: jest.fn(() => builder),
      addOrderBy: jest.fn(() => builder),
      offset: jest.fn(() => builder),
      limit: jest.fn(() => builder),
      getRawAndEntities: jest.fn().mockResolvedValue({
        entities: [asset],
        raw: [{ ownerName: 'Student One', ownerEmail: 'student@test' }],
      }),
    };
    const repo = { createQueryBuilder: jest.fn(() => builder) };
    const media = new MediaService(
      repo as never,
      { get: jest.fn() } as never,
      {} as never,
    );
    const query = Object.assign(new MediaQueryDto(), {
      ownerId: 'student-1',
      contextType: MediaContextType.JOURNAL,
      search: '50%_off',
      page: 2,
      pageSize: 1,
    });

    await expect(
      media.adminList(actor(UserRole.ADMIN), query),
    ).resolves.toEqual({
      data: [
        expect.objectContaining({
          id: 'media-1',
          owner: {
            id: 'student-1',
            name: 'Student One',
            email: 'student@test',
          },
          storageStatus: 'DRIVE',
          previewPath: '/media/drive-images/drive-1',
        }),
      ],
      total: 1,
      page: 2,
      pageSize: 1,
    });
    expect(builder.andWhere).toHaveBeenCalledWith('asset.ownerId = :ownerId', {
      ownerId: 'student-1',
    });
    expect(builder.andWhere).toHaveBeenCalledWith(
      'asset.contextType = :contextType',
      { contextType: MediaContextType.JOURNAL },
    );
    expect(builder.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('ILIKE :search'),
      { search: '%50\\%\\_off%' },
    );
    expect(builder.offset).toHaveBeenCalledWith(1);
    expect(builder.limit).toHaveBeenCalledWith(1);
  });

  it('rejects non-admin callers before querying media', async () => {
    const createQueryBuilder = jest.fn();
    const media = new MediaService(
      { createQueryBuilder } as never,
      { get: jest.fn() } as never,
      {} as never,
    );

    await expect(
      media.adminList(actor(UserRole.STUDENT), new MediaQueryDto()),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(createQueryBuilder).not.toHaveBeenCalled();
  });
});
