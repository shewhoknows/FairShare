FROM node:20-alpine AS base

# Install dependencies for Prisma binary engine
RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

# ── Install dependencies ──────────────────────────────────────────────────────
FROM base AS deps
COPY package.json package-lock.json ./
COPY apps/web/package.json ./apps/web/package.json
# Skip postinstall (prisma generate) during install; we run it explicitly
RUN npm ci --ignore-scripts

# ── Build ─────────────────────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client
RUN npx prisma generate --schema apps/web/prisma/schema.prisma

# Ensure public dir exists (may be empty)
RUN mkdir -p /app/apps/web/public

# Build Next.js
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ── Production runner ─────────────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy public assets
COPY --from=builder /app/apps/web/public ./apps/web/public

# Copy Next.js build output (standalone mode not enabled, so copy full .next)
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/apps/web/prisma ./apps/web/prisma

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Migrate, optionally seed, then start
CMD ["sh", "-c", "npx prisma migrate deploy --schema apps/web/prisma/schema.prisma && [ \"$SEED_ON_START\" = 'true' ] && npm run db:seed; npm run start"]
# Build Tue May 12 18:51:31 IST 2026
