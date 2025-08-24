FROM n8nio/n8n:latest
USER root

# Install ffmpeg and enhanced media processing tools
RUN apk add --no-cache \
    ffmpeg \
    imagemagick \
    exiftool \
    mediainfo \
    sox \
    ghostscript \
    python3 \
    py3-pip \
    && rm -rf /var/cache/apk/*

# Install Python libraries for advanced media processing
RUN pip3 install --no-cache-dir --break-system-packages \
    pydub \
    Pillow \
    && rm -rf /root/.cache

# Create media directories with proper permissions for node user
# UID 1000 is the node user in the n8n container
RUN mkdir -p /data/media /data/temp && \
    chown -R 1000:1000 /data/media /data/temp && \
    chmod 775 /data/media /data/temp

USER node
WORKDIR /data
