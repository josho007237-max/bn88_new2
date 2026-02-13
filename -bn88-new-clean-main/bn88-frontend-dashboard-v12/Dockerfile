# ===============================================
# BN88 Frontend Dashboard - Multi-stage Docker Build
# ===============================================

# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# ===============================================
# Stage 2: Production with Nginx
FROM nginx:alpine AS production

# Healthcheck uses wget
RUN apk add --no-cache wget

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 5555

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5555/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
