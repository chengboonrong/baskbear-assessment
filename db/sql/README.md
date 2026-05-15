# Raw SQL

`init.sql` is the Prisma-generated migration for the initial schema. It is
identical to `apps/api/prisma/migrations/20260515102556_init/migration.sql`
and is exported here for reviewers who want to read the schema without
installing Node/Prisma.

Apply it directly with `mysql baskbear < init.sql`, or — preferred — use
`npx prisma migrate deploy` from `apps/api/`, which keeps the migration
history in sync with future schema changes.
