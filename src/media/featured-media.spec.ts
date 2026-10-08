import { In } from 'typeorm';
import { MediaService } from './media.service';
import { MediaContextType } from './media-context';

function fixture() {
  const asset = {
    id: 'asset',
    remoteUrl: 'https://drive.google.com/uc?id=drive-file',
    driveFileId: 'drive-file',
    mimeType: 'image/webp',
  };
  const repo = {
    find: jest.fn().mockResolvedValue([asset]),
    findOne: jest.fn().mockResolvedValue(asset),
    remove: jest.fn().mockResolvedValue(asset),
  };
  const drive = {
    remove: jest.fn().mockResolvedValue(undefined),
    download: jest
      .fn()
      .mockResolvedValue({
        buffer: Buffer.from('image'),
        mimeType: 'image/webp',
      }),
  };
  return {
    asset,
    repo,
    drive,
    service: new MediaService(repo as never, {} as never, drive as never),
  };
}

describe('Featured media storage', () => {
  it('only deletes registered featured media matching removed URLs', async () => {
    const { service, repo, drive, asset } = fixture();
    await service.removeFeaturedMedia([asset.remoteUrl]);
    expect(repo.find).toHaveBeenCalledWith({
      where: {
        contextType: MediaContextType.FEATURED_TRADE,
        remoteUrl: In([asset.remoteUrl]),
      },
    });
    expect(drive.remove).toHaveBeenCalledWith('drive-file');
    expect(repo.remove).toHaveBeenCalledWith(asset);
  });
  it('keeps asset record when Drive deletion fails', async () => {
    const { service, repo, drive, asset } = fixture();
    drive.remove.mockRejectedValueOnce(new Error('offline'));
    await expect(
      service.removeFeaturedMedia([asset.remoteUrl]),
    ).rejects.toThrow('offline');
    expect(repo.remove).not.toHaveBeenCalled();
  });
  it('serves Drive image bytes only for featured media', async () => {
    const { service, repo, drive } = fixture();
    expect(await service.downloadFeaturedImage('drive-file')).toEqual({
      buffer: Buffer.from('image'),
      mimeType: 'image/webp',
    });
    expect(repo.findOne).toHaveBeenCalledWith({
      where: {
        driveFileId: 'drive-file',
        contextType: MediaContextType.FEATURED_TRADE,
      },
    });
    expect(drive.download).toHaveBeenCalledWith('drive-file');
    repo.findOne.mockResolvedValueOnce(null);
    await expect(service.downloadFeaturedImage('missing')).rejects.toThrow(
      'không tồn tại',
    );
  });
});
