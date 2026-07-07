FROM python:3.13

USER root

WORKDIR /app

ENV AIRFLOW_HOME=/app
ENV AIRFLOW__CORE__LOAD_EXAMPLES=false
ENV AIRFLOW__COSMOS__ENABLE_TELEMETRY=false

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install uv

RUN uv init 

RUN uv add astronomer-cosmos dbt-spark[PyHive]

RUN mkdir dags dbt

COPY ./models ./dbt/teratai/models

COPY ./macros ./dbt/teratai/macros

COPY ./profiles.yml ./dbt/teratai/profiles.yml

COPY ./dags ./dags

EXPOSE 8080