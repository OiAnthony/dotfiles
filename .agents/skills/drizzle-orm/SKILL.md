---
name: drizzle-orm
description: >
  Drizzle ORM best practices, schema patterns, relational queries, CRUD operations,
  migrations, and TypeScript type inference. Activate when working with drizzle-orm
  imports, database schemas, queries, or migrations in any TypeScript project.
---

# Drizzle ORM

Drizzle is a lightweight (~7.4kb), zero-dependency, TypeScript-first ORM supporting PostgreSQL, MySQL, SQLite, SingleStore, MSSQL, and CockroachDB. It is serverless-ready by design.

**Always check the project's installed version before writing code.** Drizzle v1 RC introduced breaking changes to relations and relational queries. Look for `defineRelations` (v1 RC) vs `relations` (legacy) in existing code.

**For any topic not covered here, fetch the official docs:**
- Index: `https://orm.drizzle.team/llms.txt`
- Full: `https://orm.drizzle.team/llms-full.txt`

---

## Schema Declaration

Each SQL dialect has its own import path and table function.

### PostgreSQL

```ts
import { pgTable, serial, text, integer, boolean, timestamp, pgEnum } from "drizzle-orm/pg-core";

export const roleEnum = pgEnum("role", ["admin", "user", "guest"]);

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  role: roleEnum("role").default("user"),
  verified: boolean("verified").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});
```

### MySQL

```ts
import { mysqlTable, serial, varchar, int, boolean, timestamp, mysqlEnum } from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 255 }).notNull(),
  email: varchar("email", { length: 255 }).notNull().unique(),
  role: mysqlEnum("role", ["admin", "user", "guest"]).default("user"),
  verified: boolean("verified").notNull().default(false),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});
```

### SQLite

```ts
import { sqliteTable, integer, text } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  role: text("role", { enum: ["admin", "user", "guest"] }).default("user"),
  // SQLite has no native boolean — use integer with mode: "boolean"
  verified: integer("verified", { mode: "boolean" }).notNull().default(false),
  // SQLite has no native timestamp — use text with SQL expression
  createdAt: text("created_at").notNull().default("(datetime('now'))"),
});
```

### Indexes and Constraints

```ts
import { pgTable, text, integer, index, uniqueIndex } from "drizzle-orm/pg-core";

export const posts = pgTable("posts", {
  id: integer("id").primaryKey().generatedAlwaysAsIdentity(),
  title: text("title").notNull(),
  authorId: integer("author_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  slug: text("slug").notNull(),
}, (t) => [
  index("posts_author_idx").on(t.authorId),
  uniqueIndex("posts_slug_idx").on(t.slug),
]);
```

### Type Inference

```ts
import type { InferSelectModel, InferInsertModel } from "drizzle-orm";

type User = InferSelectModel<typeof users>;       // or typeof users.$inferSelect
type NewUser = InferInsertModel<typeof users>;     // or typeof users.$inferInsert
```

---

## Relations

### v1 RC — `defineRelations()` (preferred for new projects)

```ts
import { defineRelations } from "drizzle-orm";

export const relations = defineRelations({ users, posts, comments }, (r) => ({
  users: {
    posts: r.many.posts(),
    profile: r.one.profiles(),
  },
  posts: {
    author: r.one.users({
      from: r.posts.authorId,
      to: r.users.id,
    }),
    comments: r.many.comments(),
  },
  comments: {
    post: r.one.posts({
      from: r.comments.postId,
      to: r.posts.id,
    }),
    author: r.one.users({
      from: r.comments.authorId,
      to: r.users.id,
    }),
  },
}));
```

**Disambiguation with aliases** (when a table has multiple FK references to the same table):

```ts
export const relations = defineRelations({ users, posts }, (r) => ({
  users: {
    authoredPosts: r.many.posts({ alias: "author" }),
    reviewedPosts: r.many.posts({ alias: "reviewer" }),
  },
  posts: {
    author: r.one.users({ from: r.posts.authorId, to: r.users.id, alias: "author" }),
    reviewer: r.one.users({ from: r.posts.reviewerId, to: r.users.id, alias: "reviewer" }),
  },
}));
```

### Legacy — `relations()` (pre-v1 RC)

```ts
import { relations } from "drizzle-orm";

export const usersRelations = relations(users, ({ one, many }) => ({
  posts: many(posts),
  profile: one(profiles, { fields: [users.profileId], references: [profiles.id] }),
}));

export const postsRelations = relations(posts, ({ one, many }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] }),
  comments: many(comments),
}));
```

---

## Relational Queries (RQB v2)

Requires passing `schema` when creating the drizzle instance:

```ts
import * as schema from "./schema";
import { drizzle } from "drizzle-orm/libsql"; // or /node-postgres, /mysql2, etc.

const db = drizzle({ client, schema });
```

### findMany / findFirst

```ts
const usersWithPosts = await db.query.users.findMany({
  columns: { id: true, name: true },
  where: { verified: { eq: true } },           // object syntax (v2)
  // where: (users, { eq }) => eq(users.verified, true),  // callback syntax (also works)
  with: {
    posts: {
      columns: { id: true, title: true },
      where: { published: { eq: true } },
      limit: 5,
      orderBy: { createdAt: "desc" },
      with: {
        comments: { limit: 3 },
      },
    },
  },
  limit: 10,
  offset: 0,
  orderBy: { name: "asc" },
});

const user = await db.query.users.findFirst({
  where: { id: { eq: 1 } },
  with: { posts: true },
});
```

### Where clause operators (object syntax)

```ts
where: {
  id: { gt: 5 },
  name: { like: "%john%" },
  OR: [
    { role: { eq: "admin" } },
    { verified: { eq: true } },
  ],
}
```

### Prepared statements

```ts
const prepared = db.query.users.findMany({
  limit: sql.placeholder("limit"),
  offset: sql.placeholder("offset"),
  where: { id: { eq: sql.placeholder("id") } },
}).prepare();

const result = await prepared.execute({ limit: 10, offset: 0, id: 5 });
```

---

## SQL-like CRUD

### Select

```ts
import { eq, and, or, like, gt, lt, isNull, desc, asc, sql, count } from "drizzle-orm";

const allUsers = await db.select().from(users);

const filtered = await db.select()
  .from(users)
  .where(and(eq(users.role, "admin"), gt(users.id, 5)))
  .orderBy(desc(users.createdAt))
  .limit(10);

// Partial select
const names = await db.select({ id: users.id, name: users.name }).from(users);

// With joins
const result = await db.select()
  .from(posts)
  .leftJoin(users, eq(posts.authorId, users.id))
  .where(eq(users.verified, true));

// Aggregation
const [{ total }] = await db.select({ total: count() }).from(users);
```

### Insert

```ts
await db.insert(users).values({ name: "Alice", email: "alice@example.com" });

// Bulk insert
await db.insert(users).values([
  { name: "Bob", email: "bob@example.com" },
  { name: "Carol", email: "carol@example.com" },
]);

// Insert returning (PostgreSQL/SQLite)
const [newUser] = await db.insert(users).values({ name: "Dave", email: "dave@example.com" }).returning();

// Upsert (onConflictDoUpdate)
await db.insert(users)
  .values({ email: "alice@example.com", name: "Alice Updated" })
  .onConflictDoUpdate({
    target: users.email,
    set: { name: "Alice Updated" },
  });

// Upsert (onConflictDoNothing)
await db.insert(users)
  .values({ email: "alice@example.com", name: "Alice" })
  .onConflictDoNothing({ target: users.email });
```

### Update

```ts
await db.update(users).set({ verified: true }).where(eq(users.id, 1));

// Increment pattern
await db.update(users)
  .set({ loginCount: sql`${users.loginCount} + 1` })
  .where(eq(users.id, 1));

// Update returning (PostgreSQL/SQLite)
const [updated] = await db.update(users).set({ name: "New Name" }).where(eq(users.id, 1)).returning();
```

### Delete

```ts
await db.delete(users).where(eq(users.id, 1));

// Delete returning (PostgreSQL/SQLite)
const [deleted] = await db.delete(users).where(eq(users.id, 1)).returning();
```

---

## Transactions

```ts
await db.transaction(async (tx) => {
  const [user] = await tx.insert(users).values({ name: "Alice", email: "a@b.com" }).returning();
  await tx.insert(posts).values({ title: "First Post", authorId: user.id });
});

// Nested transactions (savepoints)
await db.transaction(async (tx) => {
  await tx.insert(users).values({ name: "Bob", email: "b@b.com" });
  await tx.transaction(async (tx2) => {
    await tx2.insert(posts).values({ title: "Nested", authorId: 1 });
  });
});

// Rollback
await db.transaction(async (tx) => {
  await tx.insert(users).values({ name: "Will Rollback", email: "r@b.com" });
  tx.rollback(); // throws, aborts transaction
});
```

---

## Migrations (Drizzle Kit)

### Config file (`drizzle.config.ts`)

```ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",       // "postgresql" | "mysql" | "sqlite" | "turso" | "singlestore"
  schema: "./src/schema",     // path to schema file(s)
  out: "./drizzle",           // migration output directory
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
```

### Commands

```bash
npx drizzle-kit generate    # Generate migration SQL from schema diff
npx drizzle-kit migrate     # Apply pending migrations
npx drizzle-kit push        # Push schema directly (dev only, no migration files)
npx drizzle-kit pull        # Introspect DB and generate schema
npx drizzle-kit studio      # Open Drizzle Studio GUI
npx drizzle-kit check       # Verify migration consistency
```

**`push` vs `generate + migrate`:**
- Use `push` for rapid prototyping (no migration files created)
- Use `generate` + `migrate` for production workflows with version-controlled migrations

---

## Validation Integration

### drizzle-zod

```ts
import { createInsertSchema, createSelectSchema } from "drizzle-zod";

const insertUserSchema = createInsertSchema(users, {
  email: (schema) => schema.email(),
  name: (schema) => schema.min(2).max(100),
});

const selectUserSchema = createSelectSchema(users);

type InsertUser = z.infer<typeof insertUserSchema>;
```

### drizzle-valibot

```ts
import { createInsertSchema, createSelectSchema } from "drizzle-valibot";

const insertUserSchema = createInsertSchema(users);
```

---

## Common Gotchas

1. **SQLite FK constraints off by default** — Run `PRAGMA foreign_keys = ON` after connecting. libsql/Turso may not support this via HTTP.

2. **SQLite has no native boolean** — Use `integer("col", { mode: "boolean" })` to map 0/1 to false/true.

3. **SQLite has no native timestamp** — Use `text` with `default("(datetime('now'))")` or `integer` with `{ mode: "timestamp" }`.

4. **`returning()` not available on MySQL** — Only PostgreSQL and SQLite support `.returning()`.

5. **Relations are separate from FK constraints** — Drizzle relations (for RQB) are TypeScript-only declarations. You still need `.references()` on columns for actual DB-level foreign keys.

6. **Schema must be passed to `drizzle()`** — Relational queries (`db.query.*`) only work when `schema` is provided to the drizzle constructor.

7. **`onConflictDoUpdate` target** — Must match a unique constraint or primary key. For composite unique constraints, pass an array.

8. **v1 RC migration** — If upgrading from legacy relations to v1 RC, replace `relations()` with `defineRelations()`. See https://orm.drizzle.team/docs/relations-v1-v2

---

## Connection Patterns

### libsql / Turso (SQLite)

```ts
import { createClient } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";

const client = createClient({ url: process.env.DATABASE_URL! });
const db = drizzle({ client, schema });
```

### Bun SQLite

```ts
import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";

const sqlite = new Database("mydb.sqlite");
const db = drizzle({ client: sqlite, schema });
```

### node-postgres (PostgreSQL)

```ts
import { drizzle } from "drizzle-orm/node-postgres";

const db = drizzle(process.env.DATABASE_URL!, { schema });
```

### Neon Serverless (PostgreSQL)

```ts
import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";

const sql = neon(process.env.DATABASE_URL!);
const db = drizzle({ client: sql, schema });
```

### Cloudflare D1 (SQLite)

```ts
import { drizzle } from "drizzle-orm/d1";

export default {
  async fetch(request: Request, env: Env) {
    const db = drizzle(env.DB, { schema });
  },
};
```

---

## Dynamic Query Building

```ts
import { SQL } from "drizzle-orm";

const buildQuery = (filters: { name?: string; role?: string; verified?: boolean }) => {
  const conditions: SQL[] = [];

  if (filters.name) conditions.push(like(users.name, `%${filters.name}%`));
  if (filters.role) conditions.push(eq(users.role, filters.role));
  if (filters.verified !== undefined) conditions.push(eq(users.verified, filters.verified));

  return db.select().from(users).where(and(...conditions));
};
```

---

## The `sql` Template Tag

```ts
import { sql } from "drizzle-orm";

// Raw SQL expressions
const result = await db.select({
  lowered: sql<string>`lower(${users.name})`,
  total: sql<number>`count(*)`.as("total"),
}).from(users);

// In where clauses
await db.select().from(users).where(sql`${users.id} = ${someId}`);

// Type-safe custom expressions
const increment = sql`${users.loginCount} + 1`;
await db.update(users).set({ loginCount: increment }).where(eq(users.id, 1));
```
