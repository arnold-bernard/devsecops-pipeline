FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy the application source
COPY . .

# Build the application
RUN npm run build

# ===========================================================
# Stage 2: Production Image
# ===========================================================
FROM node:20-alpine

WORKDIR /app

# Copy only what is needed from the build stage
COPY --from=builder /app .

# Expose Juice Shop port
EXPOSE 3000

# Run as a non-root user
USER node

# Start the application
CMD ["npm", "start"]