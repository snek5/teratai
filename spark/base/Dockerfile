FROM spark:4.1.2-scala2.13-java21-python3-ubuntu

USER root

# -----------------------------
# System utilities
# -----------------------------
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    ca-certificates \
    tini \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Spark / Iceberg versions
# -----------------------------
ARG ICEBERG_VERSION=1.11.0
ARG HADOOP_AWS_VERSION=3.4.1
ARG AWS_SDK_VERSION=2.25.60
ARG POSTGRES_JDBC_VERSION=42.7.3

# -----------------------------
# Create jars directory
# -----------------------------
RUN mkdir -p /opt/spark/jars-extra

# -----------------------------
# Download Iceberg runtime
# -----------------------------
RUN curl -L -o /opt/spark/jars-extra/iceberg-spark-runtime.jar \
https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-4.1_2.13-${ICEBERG_VERSION}.jar

# -----------------------------
# Hadoop AWS (S3 support)
# -----------------------------
RUN curl -L -o /opt/spark/jars-extra/hadoop-aws.jar \
https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar

# -----------------------------
# AWS SDK bundle (required by hadoop-aws)
# -----------------------------
RUN curl -L -o /opt/spark/jars-extra/aws-sdk-bundle.jar \
https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_VERSION}/bundle-${AWS_SDK_VERSION}.jar

# -----------------------------
# PostgreSQL JDBC driver
# -----------------------------
RUN curl -L -o /opt/spark/jars-extra/postgresql.jar \
https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar

# -----------------------------
# Make Spark load extra jars automatically
# -----------------------------
ENV SPARK_EXTRA_JARS=/opt/spark/jars-extra/*

# -----------------------------
# Entrypoint handling
# -----------------------------
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]