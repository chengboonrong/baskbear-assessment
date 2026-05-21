// Prisma 7 moved the datasource URL out of schema.prisma. The CLI
// (migrate / validate / generate / studio) reads it from here. Runtime
// instantiation of PrismaClient is in src/prisma/prisma.service.ts and
// uses @prisma/adapter-mariadb against the same DATABASE_URL.
import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'ts-node prisma/seed.ts',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
