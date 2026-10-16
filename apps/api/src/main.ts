import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  const configuredOrigins = process.env.ADMIN_ORIGIN?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  app.enableCors({
    origin: configuredOrigins?.length ? configuredOrigins : true,
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  await app.listen(process.env.PORT ?? 3001, '0.0.0.0');
}
void bootstrap();
