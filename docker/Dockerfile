FROM node:22-bookworm-slim

# Install git and sudo (required by openclaw dependencies and entrypoint script)
RUN apt-get update && apt-get install -y git sudo && rm -rf /var/lib/apt/lists/*

# Install openclaw globally
RUN npm install -g openclaw@latest

# Create non-root user
RUN useradd -m -s /bin/bash openclaw
# Add openclaw user to sudo group and configure sudoers
RUN usermod -aG sudo openclaw
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# Copy the entrypoint script and make it executable
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /home/openclaw

# Expose Gateway port
EXPOSE 18789

# Set the entrypoint to our script
ENTRYPOINT ["entrypoint.sh"]

# Start the OpenClaw Gateway
CMD ["openclaw", "gateway", "--port", "18789", "--allow-unconfigured"]
