FROM python:3.13

USER root

WORKDIR /app

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install uv

RUN uv init 

RUN uv install astronomer-cosmos dbt-spark[PyHive]
