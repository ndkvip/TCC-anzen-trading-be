import {
  INestApplication,
  UnauthorizedException,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MediaContextType } from '../media/media-context';
import { HomePostsController } from './home-posts.controller';
import { FeaturedTradeService } from './featured-trade.service';
import { FeaturedTradeImagesService } from './featured-trade-images.service';

describe('Home posts HTTP contract', () => {
  let app: INestApplication;
  const service = {
    publicHomePosts: jest.fn(async () => []),
    adminList: jest.fn(async () => []),
    createHomePost: jest.fn(async (body) => body),
    update: jest.fn(async (_id, body) => body),
    remove: jest.fn(async () => ({ success: true })),
  };
  const images = {
    upload: jest.fn(async () => ({ imageUrls: ['/cover.webp'] })),
  };
  const body = {
    title: 'Home news',
    contentBlocks: [{ type: 'text', text: 'An article' }],
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [HomePostsController],
      providers: [
        { provide: FeaturedTradeService, useValue: service },
        { provide: FeaturedTradeImagesService, useValue: images },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context) => {
          const req = context.switchToHttp().getRequest();
          const role = req.headers.authorization?.split(' ')[1];
          if (!role) throw new UnauthorizedException();
          req.user = { sub: 'editor', role };
          return true;
        },
      })
      .compile();
    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();
  });
  afterAll(async () => app.close());
  beforeEach(() => jest.clearAllMocks());

  it('lets guests read active home posts without a date or account', async () => {
    await request(app.getHttpServer()).get('/home-posts').expect(200, []);
    expect(service.publicHomePosts).toHaveBeenCalledWith();
    expect(service.adminList).not.toHaveBeenCalled();
  });

  it.each([
    ['get', '/home-posts/admin'],
    ['post', '/home-posts'],
    ['patch', '/home-posts/id'],
    ['delete', '/home-posts/id'],
    ['post', '/home-posts/uploads'],
  ])(
    'protects %s %s with authentication and the real admin roles guard',
    async (method, url) => {
      await request(app.getHttpServer())[method](url).send(body).expect(401);
      await request(app.getHttpServer())
        [method](url)
        .set('Authorization', 'Bearer STUDENT')
        .send(body)
        .expect(403);
      expect(service.createHomePost).not.toHaveBeenCalled();
      expect(service.update).not.toHaveBeenCalled();
      expect(service.remove).not.toHaveBeenCalled();
      expect(images.upload).not.toHaveBeenCalled();
    },
  );

  it('accepts text-only posts without cover/week and routes admin operations to HOME_POST', async () => {
    await request(app.getHttpServer())
      .post('/home-posts')
      .set('Authorization', 'Bearer ADMIN')
      .send(body)
      .expect(201, body);
    expect(service.createHomePost).toHaveBeenCalledWith(body);
    await request(app.getHttpServer())
      .get('/home-posts/admin')
      .set('Authorization', 'Bearer ADMIN')
      .expect(200);
    expect(service.adminList).toHaveBeenCalledWith('HOME_POST');
    await request(app.getHttpServer())
      .patch('/home-posts/id')
      .set('Authorization', 'Bearer ADMIN')
      .send({ isActive: false })
      .expect(200);
    expect(service.update).toHaveBeenCalledWith(
      'id',
      { isActive: false },
      'HOME_POST',
    );
    await request(app.getHttpServer())
      .delete('/home-posts/id')
      .set('Authorization', 'Bearer ADMIN')
      .expect(200);
    expect(service.remove).toHaveBeenCalledWith('id', 'HOME_POST');
  });

  it.each([
    { ...body, placement: 'FEATURED_TRADE' },
    { ...body, weekStart: '2026-11-09' },
    { ...body, contentBlocks: [{ type: 'html', text: 'bad' }] },
    { ...body, title: null },
    { ...body, summary: null },
    { ...body, contentBlocks: null },
    { ...body, isActive: 'true' },
    { ...body, contentBlocks: [{ type: 'text', text: 5 }] },
  ])('rejects invalid or cross-section payload %p', async (input) => {
    await request(app.getHttpServer())
      .post('/home-posts')
      .set('Authorization', 'Bearer ADMIN')
      .send(input)
      .expect(400);
    expect(service.createHomePost).not.toHaveBeenCalled();
  });

  it('rejects null update fields rather than causing a server error', async () => {
    await request(app.getHttpServer())
      .patch('/home-posts/id')
      .set('Authorization', 'Bearer ADMIN')
      .send({ title: null, contentBlocks: null })
      .expect(400);
    expect(service.update).not.toHaveBeenCalled();
  });

  it('routes image uploads through the separate home post media context', async () => {
    await request(app.getHttpServer())
      .post('/home-posts/uploads')
      .set('Authorization', 'Bearer ADMIN')
      .attach('files', Buffer.from('image'), {
        filename: 'cover.png',
        contentType: 'image/png',
      })
      .expect(201);
    expect(images.upload).toHaveBeenCalledWith(
      [expect.objectContaining({ originalname: 'cover.png' })],
      { sub: 'editor', role: 'ADMIN' },
      MediaContextType.HOME_POST,
    );
  });
});
