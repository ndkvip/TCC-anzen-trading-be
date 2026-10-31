import dataSource from './database/data-source';
import { RedNews } from './red-news/red-news.entity';
import { RedNewsService } from './red-news/red-news.service';

async function main() {
  await dataSource.initialize();
  try {
    const service = new RedNewsService(dataSource.getRepository(RedNews));
    const result = await service.syncFromCalendar({ force: true });
    console.log(JSON.stringify(result));
    if (result.skipped) process.exitCode = 1;
  } finally {
    await dataSource.destroy();
  }
}

void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
