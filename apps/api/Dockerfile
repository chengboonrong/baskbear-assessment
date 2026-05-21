# Multi-stage build for the NestJS API.
#
# Stage 1 (builder): install all deps (postinstall runs `prisma generate`,
# which emits the client into src/generated/prisma) and run `nest build`.
# Stage 2 (runtime): copy compiled dist + node_modules + prisma assets so the
# container can run migrations on boot and start the compiled server.

FROM node:20-bookworm-slim AS builder
WORKDIR /app

# Prisma needs OpenSSL even with the MariaDB driver adapter.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./prisma.config.ts
# `npm ci` triggers postinstall → `prisma generate` → src/generated/prisma/*.ts.
# Prisma 7's prisma.config.ts eagerly resolves DATABASE_URL, so we feed it a
# dummy at build time (generate doesn't connect to the DB).
ENV DATABASE_URL="mysql://build:build@build:3306/build"
RUN npm ci

COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN npm run build


FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Keep all deps (incl. dev) so `prisma migrate deploy` and `ts-node prisma/seed.ts`
# both work inside the container.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/tsconfig.json ./tsconfig.json
# `npm run seed` uses ts-node and imports `../src/generated/prisma/client`.
# The generated client is produced by postinstall in the builder; ship it so
# `docker compose exec api npm run seed` works from the runtime image.
COPY --from=builder /app/src/generated ./src/generated

EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]
