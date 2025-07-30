echo '# Use official Node.js 18 LTS image as the base
FROM node:18

# Install FFmpeg
RUN apt-get update && apt-get install -y ffmpeg

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json .
RUN npm install

# Copy the rest of the application
COPY . .

# Create directories for uploads and converted files
RUN mkdir -p uploads converted

# Expose the port
EXPOSE 8080

# Start the server
CMD ["node", "server.js"]' > Dockerfile