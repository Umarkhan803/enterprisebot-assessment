# Build stage
FROM node:22.14.0-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY server.js .

# Runtime stage
FROM node:22.14.0-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Create and use a non-root user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./server.js
COPY --from=builder /app/package*.json ./

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

CMD ["node", "server.js"]