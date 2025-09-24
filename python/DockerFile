# python/Dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

# Copy & install deps first (cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then app code
COPY . .

# Drop privileges
RUN useradd -m agent && chown -R agent:agent /app
USER agent

CMD ["python","-u","main.py"]