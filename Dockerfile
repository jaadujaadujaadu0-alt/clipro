FROM docker.io/library/python:3.10-slim

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy all repository files directly
COPY . .

# Grant execute permissions and run
RUN chmod +x a.sh
CMD ["./a.sh"]
