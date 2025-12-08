# Use official Node.js 18 LTS image as the base
FROM node:18

# Install FFmpeg
RUN apt-get update && apt-get install -y ffmpeg

# Set working directory inside the container
WORKDIR /app

# Copy package.json from audio-converter/ and install dependencies
COPY audio-converter/package.json .
RUN npm install

# Copy the rest of the application from audio-converter/
COPY audio-converter/ .

# Create directories for uploads and converted files
RUN mkdir -p uploads converted

# Expose the port
EXPOSE 8080

# Start the server
CMD ["node", "server.js"]