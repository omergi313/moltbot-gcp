FROM node:22-bookworm-slim

# Install git (required by openclaw dependencies)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Install openclaw globally
RUN npm install -g openclaw@latest

# Create non-root user
RUN useradd -m -s /bin/bash openclaw

# Set working directory
WORKDIR /home/openclaw

# Switch to non-root user
USER openclaw

# Expose Gateway port
EXPOSE 18789

# Start the OpenClaw Gateway
CMD ["openclaw", "gateway", "--port", "18789", "--allow-unconfigured"]
