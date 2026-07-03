# Teratai Lakehouse Local Stack

This repository contains a local lakehouse environment powered by Spark, Iceberg REST catalog, MinIO, and PostgreSQL.

## Overview

The stack is designed to run locally with Docker Compose. It provides:

- a PostgreSQL-based Iceberg metadata catalog
- MinIO object storage as an S3-compatible warehouse
- Iceberg REST catalog service for Spark metadata access
- Spark master and workers for execution
- Spark Thrift Server for SQL/JDBC access

## Services

- `postgres`
  - PostgreSQL 15 with `POSTGRES_DB=iceberg_catalog`
  - stores Iceberg catalog metadata
- `minio`
  - S3-compatible object store for Iceberg table files
  - exposes MinIO API on port `9000` and console on `9001`
- `iceberg-rest`
  - Iceberg REST catalog service
  - connects to PostgreSQL at `jdbc:postgresql://postgres:5432/iceberg_catalog`
  - uses MinIO as the storage backend
- `spark-master`
  - Spark master node that schedules work
- `spark-worker-1` / `spark-worker-2`
  - Spark workers that execute tasks
- `spark-thrift`
  - Spark Thrift Server for SQL clients
  - depends on `spark-master` and `iceberg-rest`

## Architecture Diagram

```mermaid
flowchart LR
  subgraph lakehouse-net
    PG[PostgreSQL\n(iceberg_catalog)]
    MINIO[MinIO\nS3 Storage]
    ICEBERG[Iceberg REST Catalog]
    SPARK_MASTER[Spark Master]
    SPARK_WORKER1[Spark Worker 1]
    SPARK_WORKER2[Spark Worker 2]
    THRIFT[Spark Thrift Server]
  end

  MINIO -->|S3 endpoint| ICEBERG
  PG -->|JDBC catalog URI| ICEBERG
  ICEBERG -->|REST catalog| THRIFT
  THRIFT -->|master URL| SPARK_MASTER
  SPARK_MASTER -->|registers| SPARK_WORKER1
  SPARK_MASTER -->|registers| SPARK_WORKER2
  THRIFT -->|reads/writes| MINIO
  THRIFT -->|reads/writes| ICEBERG
  SPARK_MASTER -->|logs| /tmp/spark-events
  SPARK_WORKER1 -->|logs| /tmp/spark-events
  SPARK_WORKER2 -->|logs| /tmp/spark-events
```

## How it works

1. `postgres` initializes the `iceberg_catalog` database using `POSTGRES_DB`.
2. `minio` starts and exposes an S3-compatible object store.
3. `iceberg-rest` starts after PostgreSQL and MinIO are healthy.
4. `spark-master` starts and waits for worker registration.
5. `spark-worker-1` and `spark-worker-2` connect to the Spark master.
6. `spark-thrift` starts and connects to the Spark master and Iceberg REST catalog.
7. Spark uses the Iceberg REST catalog for metadata and MinIO for table storage.

## Important notes

- `iceberg-rest` must be running for Spark to access the Iceberg catalog because Spark is configured to use the REST catalog at `http://iceberg-rest:8181`.
- The PostgreSQL healthcheck should explicitly specify the Iceberg database:
  - `pg_isready -U iceberg -d iceberg_catalog`
- If `spark-thrift` mounts `./spark/spark-thrift/scripts/entrypoint.sh`, ensure the file is executable:
  - `chmod +x spark/spark-thrift/scripts/entrypoint.sh`
- Do not use MySQL-style SQL in PostgreSQL init scripts. For example, `CREATE DATABASE IF NOT EXISTS` is invalid in Postgres.

## Local usage

Start the stack:

```bash
docker compose up --build
```

Start detached:

```bash
docker compose up --build -d
```

Stop the stack:

```bash
docker compose down
```

## Ports

- `5432` → PostgreSQL
- `9000` → MinIO API
- `9001` → MinIO console
- `8181` → Iceberg REST catalog
- `7077` → Spark Master
- `8080` → Spark Master UI
- `8081` → Spark Worker 1 UI
- `8082` → Spark Worker 2 UI
- `10000` → Spark Thrift Server
- `4040` → Spark application UI
