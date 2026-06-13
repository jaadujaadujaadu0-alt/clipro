# Use an official lightweight Python image
FROM python:3.10-slim

# Install system dependencies (essential for running bash scripts)
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy requirements first to leverage Docker caching (if you have python dependencies)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt || echo "No requirements.txt found, skipping."

# Copy all repository files into the container
COPY . .

# Grant execute permissions to the shell script
RUN chmod +x a.sh

# Run the shell script directly
CMD ["./a.sh"]
