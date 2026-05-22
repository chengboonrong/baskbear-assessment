# Baskbear Coffee — API

NestJS 11 REST API that powers the Baskbear Coffee mobile app. Handles menus, orders, vouchers, and multi-country pricing for Malaysia, Thailand, and Singapore.

> Full setup instructions, environment variables, and architecture notes are in the [root README](../../README.md).

## Quick start

```bash
# from the repo root — start MySQL and Redis first
docker compose up -d

cd apps/api
cp .env.example .env
npm install
npx prisma migrate deploy
npm run seed           # loads menus, outlets, vouchers for MY + TH + SG
npm run start:dev      # http://localhost:3000
```

## Key commands

```bash
npm test               # run all unit tests
npm run lint           # lint and auto-fix
npx tsc --noEmit       # type-check only
npx prisma studio      # database GUI
npx prisma migrate dev --name <slug>   # create a new migration
```

## Smoke checks

```bash
curl http://localhost:3000/health
curl -H "X-Country: MY" http://localhost:3000/v1/menu | jq '.[0]'
curl -H "X-Country: TH" http://localhost:3000/v1/menu | jq '.[0]'
curl -H "X-Country: SG" http://localhost:3000/v1/menu | jq '.[0]'
```

The API accepts `Authorization: Bearer dev:demo-user-sub` locally (`DEV_AUTH_BYPASS=true` in `.env.example`) — no AWS credentials required.
