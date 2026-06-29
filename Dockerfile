FROM node:20-alpine AS builder

# Create working directory
WORKDIR /app

# Copy package files first
COPY app/juice-shop/package*.json ./

# Install dependencies
RUN npm ci

# Copy the remaining Juice Shop source code
COPY app/juice-shop/ .

# Build the application
RUN npm run build


FROM node:20-alpine

# Create working directory
WORKDIR /app

# Copy built application from builder
COPY --from=builder /app .

# Expose Juice Shop port
EXPOSE 3000

# Run as a non-root user
USER node

# Start Juice Shop
CMD ["npm", "start"]
