import { FeaturedTradeService } from './featured-trade.service';
import { FeaturedTrade } from './featured-trade.entity';

function fixture() {
  const rows: FeaturedTrade[] = [];
  const repo = {
    create: (value: Partial<FeaturedTrade>) => ({
      id: `${rows.length + 1}`,
      ...value,
    }),
    save: jest.fn(async (value: FeaturedTrade) => {
      const index = rows.findIndex((row) => row.id === value.id);
      if (index < 0) rows.push(value);
      else rows[index] = value;
      return value;
    }),
    findOne: async ({ where }: { where: Partial<FeaturedTrade> }) =>
      rows.find((row) =>
        Object.entries(where).every(([key, value]) => row[key] === value),
      ),
    find: jest.fn(async (options?: { where: Partial<FeaturedTrade> }) =>
      options?.where
        ? rows.filter((row) =>
            Object.entries(options.where).every(
              ([key, value]) => row[key] === value,
            ),
          )
        : rows,
    ),
    remove: async (value: FeaturedTrade) => {
      rows.splice(rows.indexOf(value), 1);
    },
  };
  const images = { remove: jest.fn().mockResolvedValue(undefined) };
  return {
    rows,
    repo,
    images,
    service: new FeaturedTradeService(repo as never, images as never),
  };
}

const article = (title = 'BTC') => ({
  weekStart: '2026-10-05',
  title,
  isActive: true,
  contentBlocks: [
    { type: 'text' as const, text: ' Before ' },
    { type: 'image' as const, imageUrl: 'https://example.test/chart.webp' },
    { type: 'text' as const, text: ' After ' },
  ],
});

describe('FeaturedTrade articles', () => {
  it('creates multiple articles in a week and retains mixed block order', async () => {
    const { service } = fixture();
    const first = await service.create(article());
    await service.create(article('Gold'));
    expect(first.contentBlocks.map((block) => block.type)).toEqual([
      'text',
      'image',
      'text',
    ]);
    expect(first.contentBlocks[0].text).toBe('Before');
    expect(await service.publicForWeek('2026-10-05')).toHaveLength(2);
    expect(await service.publicForWeek()).toEqual([]);
  });

  it('supports hiding an article without removing content', async () => {
    const { service } = fixture();
    const item = await service.create(article());
    await service.update(item.id, { isActive: false });
    expect(await service.publicForWeek(item.weekStart)).toEqual([]);
    expect((await service.adminList())[0].contentBlocks).toHaveLength(3);
  });

  it('clears summary and cover and removes unused media after saving', async () => {
    const { service, images } = fixture();
    const item = await service.create({
      ...article(),
      summary: 'Summary',
      coverImageUrl: 'https://example.test/chart.webp',
    });
    const updated = await service.update(item.id, {
      summary: '',
      coverImageUrl: '',
      contentBlocks: [{ type: 'text', text: 'Text only' }],
    });
    expect(updated.summary).toBeNull();
    expect(updated.coverImageUrl).toBeNull();
    expect(images.remove).toHaveBeenCalledWith([
      'https://example.test/chart.webp',
    ]);
  });

  it('does not delete media referenced by another article', async () => {
    const { service, images } = fixture();
    const first = await service.create(article());
    const second = await service.create(article('Gold'));
    await service.remove(first.id);
    expect(images.remove).toHaveBeenLastCalledWith([]);
    await service.remove(second.id);
    expect(images.remove).toHaveBeenLastCalledWith([
      'https://example.test/chart.webp',
    ]);
  });

  it('rejects empty titles/content and unknown article IDs', async () => {
    const { service } = fixture();
    await expect(service.create(article('  '))).rejects.toThrow('tiêu đề');
    await expect(
      service.create({ ...article(), contentBlocks: [] }),
    ).rejects.toThrow('ít nhất');
    await expect(
      service.update('missing', { isActive: false }),
    ).rejects.toThrow('không tồn tại');
  });

  it('does not delete images when persistence fails', async () => {
    const { service, repo, images } = fixture();
    const item = await service.create(article());
    repo.save.mockRejectedValueOnce(new Error('DB unavailable'));
    await expect(
      service.update(item.id, {
        contentBlocks: [{ type: 'text', text: 'New' }],
      }),
    ).rejects.toThrow('DB unavailable');
    expect(images.remove).not.toHaveBeenCalled();
  });

  it('keeps home posts and weekly trades in separate public/admin lists', async () => {
    const { service, repo } = fixture();
    const trade = await service.create(article());
    const post = await service.createHomePost(article('Home news'));
    expect(post.placement).toBe('HOME_POST');
    expect(trade.placement).toBe('FEATURED_TRADE');
    expect(await service.publicForWeek(trade.weekStart)).toEqual([trade]);
    expect(await service.publicHomePosts()).toEqual([post]);
    expect(repo.find).toHaveBeenLastCalledWith({
      where: { placement: 'HOME_POST', isActive: true },
      order: { createdAt: 'DESC', id: 'DESC' },
    });
    expect(await service.adminList()).toEqual([trade]);
    expect(await service.adminList('HOME_POST')).toEqual([post]);
  });

  it('home posts remain visible across weeks until hidden, and may be republished', async () => {
    const { service } = fixture();
    const post = await service.createHomePost(article());
    post.weekStart = '2020-01-06';
    expect(await service.publicHomePosts()).toEqual([post]);
    await service.update(post.id, { isActive: false }, 'HOME_POST');
    expect(await service.publicHomePosts()).toEqual([]);
    expect(await service.adminList('HOME_POST')).toHaveLength(1);
    await service.update(post.id, { isActive: true }, 'HOME_POST');
    expect(await service.publicHomePosts()).toEqual([post]);
  });

  it('cannot edit/delete another placement even with a known ID', async () => {
    const { service } = fixture();
    const post = await service.createHomePost(article());
    const trade = await service.create(article());
    await expect(service.update(post.id, { title: 'Wrong' })).rejects.toThrow(
      'không tồn tại',
    );
    await expect(service.remove(post.id)).rejects.toThrow('không tồn tại');
    await expect(
      service.update(trade.id, { title: 'Wrong' }, 'HOME_POST'),
    ).rejects.toThrow('không tồn tại');
    await expect(service.remove(trade.id, 'HOME_POST')).rejects.toThrow(
      'không tồn tại',
    );
    expect(post.title).toBe('BTC');
    expect(await service.adminList()).toEqual([trade]);
    expect(await service.adminList('HOME_POST')).toEqual([post]);
  });

  it('retains shared media across placements until the last reference is deleted', async () => {
    const { service, images } = fixture();
    const trade = await service.create(article());
    const post = await service.createHomePost(article());
    await service.remove(trade.id);
    expect(images.remove).toHaveBeenLastCalledWith([]);
    await service.remove(post.id, 'HOME_POST');
    expect(images.remove).toHaveBeenLastCalledWith([
      'https://example.test/chart.webp',
    ]);
  });
});
