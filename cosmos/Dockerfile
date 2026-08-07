FROM python:3.13

USER root

WORKDIR /app

ENV AIRFLOW_HOME=/app
ENV AIRFLOW__CORE__LOAD_EXAMPLES=false
ENV AIRFLOW__CORE__DAGS_FOLDER=/app/dags
ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor
ENV AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////app/airflow.db
ENV AIRFLOW__COSMOS__ENABLE_TELEMETRY=false

# dbt environment
ENV DBT_PROFILES_DIR=/app/dbt/teratai
ENV DBT_PROJECT_DIR=/app/dbt/teratai

# Spark Thrift connection
ENV SPARK_THRIFT_HOST=spark-thrift
ENV SPARK_THRIFT_PORT=10000

# Add Python bin to PATH
ENV PATH="/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    ca-certificates \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    vim \
    less \
    git \
    tree \
 && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel 

# Install all dependencies with regular pip
RUN pip install --no-cache-dir astronomer-cosmos dbt-spark[PyHive] apache-airflow-providers-apache-spark

# Create necessary directories
RUN mkdir -p /app/dags /app/dbt/teratai /app/logs /app/plugins

# Copy dbt project files - FIX: COPY to the correct subdirectory
COPY ./dbt /app/dbt

# Copy dags to the correct location
COPY ./dags /app/dags

# Setup Airflow (initialize DB and create admin user)
RUN airflow db init || true \
    && airflow users create \
        --username admin \
        --password admin \
        --firstname Admin \
        --lastname User \
        --role Admin \
        --email admin@example.com 2>/dev/null || true

# Install dbt dependencies
RUN cd /app/dbt/teratai && dbt deps || true

# Expose ports
EXPOSE 8080 8001 8793

# Keep container alive for interactive development
CMD ["sleep", "infinity"]