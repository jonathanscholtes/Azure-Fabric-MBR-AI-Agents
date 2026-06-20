FROM python:3.12-slim

# LibreOffice for converting completed .pptx slides to PNG thumbnails.
# Installed only in presentation-tools — not needed in insights-api.
RUN apt-get update && apt-get install -y \
        libreoffice-impress \
        --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

COPY src/ ./src/

ENV HOST=0.0.0.0
ENV PORT=80

EXPOSE 80

CMD ["python", "-m", "src.main"]
