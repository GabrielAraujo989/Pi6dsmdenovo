FROM node:22-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
# DATABASE_URL dummy só para o prisma generate compilar o schema (não conecta ao banco)
RUN DATABASE_URL=postgresql://x:x@localhost:5432/x npx prisma generate
RUN npm run build

# ── Production image ──────────────────────────────────────────────────────────
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
# --ignore-scripts evita que o postinstall do prisma tente gerar sem DATABASE_URL
RUN npm ci --ignore-scripts

COPY --from=builder /app/dist                    ./dist
COPY --from=builder /app/node_modules/.prisma    ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client
COPY prisma         ./prisma
COPY prisma.config.ts ./

EXPOSE 3000

# migrations rodam com a DATABASE_URL real injetada pelo docker-compose
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/main"]
