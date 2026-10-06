import { BadRequestException } from '@nestjs/common';
import sharp from 'sharp';
import { FeaturedTradeImagesService } from './featured-trade-images.service';
import { GoogleDriveService } from '../media/google-drive.service';

describe('FeaturedTradeImagesService', () => {
  const upload = jest.fn();
  const remove = jest.fn();
  let service: FeaturedTradeImagesService;

  beforeEach(() => {
    upload.mockReset();
    remove.mockReset();
    service = new FeaturedTradeImagesService({
      upload,
      remove,
    } as unknown as GoogleDriveService);
  });

  it('compresses uploaded images and stores them in Google Drive', async () => {
    const input = await sharp({
      create: {
        width: 3200,
        height: 1800,
        channels: 3,
        background: { r: 34, g: 85, b: 55 },
      },
    })
      .jpeg({ quality: 95 })
      .toBuffer();
    upload.mockResolvedValue({
      id: 'drive-file-1',
      remoteUrl: 'https://drive.google.com/uc?export=download&id=drive-file-1',
    });

    const result = await service.upload(
      [
        {
          buffer: input,
          size: input.length,
          mimetype: 'image/jpeg',
        } as Express.Multer.File,
      ],
      '2026-09-28',
    );

    expect(upload).toHaveBeenCalledTimes(1);
    const [buffer, options] = upload.mock.calls[0];
    const metadata = await sharp(buffer).metadata();
    expect(metadata.format).toBe('webp');
    expect(metadata.width).toBe(2560);
    expect(buffer.length).toBeLessThan(input.length);
    expect(options).toEqual(
      expect.objectContaining({
        mimeType: 'image/webp',
        folderPath: 'Giao dịch nổi bật/2026-09-28',
      }),
    );
    expect(result.imageUrls).toEqual([
      'https://drive.google.com/uc?export=download&id=drive-file-1',
    ]);
  });

  it('rejects non-image uploads before calling Drive', async () => {
    await expect(
      service.upload(
        [
          {
            buffer: Buffer.from('not an image'),
            size: 12,
            mimetype: 'application/pdf',
          } as Express.Multer.File,
        ],
        '2026-09-28',
      ),
    ).rejects.toThrow('Chỉ chấp nhận tệp hình ảnh');
    expect(upload).not.toHaveBeenCalled();
  });

  it('cleans up already uploaded Drive files when a later upload fails', async () => {
    upload
      .mockResolvedValueOnce({
        id: 'drive-file-1',
        remoteUrl: 'https://drive.google.com/uc?id=drive-file-1',
      })
      .mockRejectedValueOnce(new BadRequestException('Drive down'));
    const input = await sharp({
      create: {
        width: 20,
        height: 20,
        channels: 3,
        background: { r: 34, g: 85, b: 55 },
      },
    })
      .png()
      .toBuffer();

    await expect(
      service.upload(
        [
          {
            buffer: input,
            size: input.length,
            mimetype: 'image/png',
          } as Express.Multer.File,
          {
            buffer: input,
            size: input.length,
            mimetype: 'image/png',
          } as Express.Multer.File,
        ],
        '2026-09-28',
      ),
    ).rejects.toThrow('Drive down');
    expect(remove).toHaveBeenCalledWith('drive-file-1');
  });
});
