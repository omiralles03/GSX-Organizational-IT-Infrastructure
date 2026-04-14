FROM node:25-alpine AS builder

WORKDIR /app
COPY package*.json ./
# Install dependencies
RUN npm install


FROM node:25-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S gsxgroup && adduser -S gsxuser -u 1001 -G gsxgroup

# Copy node_modules from builder
COPY --from=builder --chown=gsxuser:gsxgroup /app/node_modules ./node_modules
# Copy source code
COPY --chown=gsxuser:gsxgroup . .

USER gsxuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
  CMD node -e "require('http').get('http://localhost:3000', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

CMD ["node", "server.mjs"]


