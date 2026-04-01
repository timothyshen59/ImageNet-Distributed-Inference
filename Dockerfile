FROM python:3.11-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .


RUN pip install --no-cache-dir \
    --prefix=/install \
    -r requirements.txt

FROM python:3.11-slim AS runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libturbojpeg0 \
    && rm -rf /var/lib/apt/lists/*


COPY --from=builder /install /usr/local

COPY gRPC/ ./gRPC/          
COPY app/ ./app/            
COPY model/ ./model/  

RUN useradd -m appuser
USER appuser 

EXPOSE 8000
EXPOSE 50051

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

