#!/usr/bin/env bash

export SPARK_HOME=/opt/spark
export SPARK_CONF_DIR=/opt/spark/conf

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

export PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

# Prevent background daemonization (important for containers)
export SPARK_NO_DAEMONIZE=true

# Optional: improve container logging determinism
export SPARK_LOG_DIR=/tmp/spark-logs

# Ensure consistent hostname resolution inside docker network
export SPARK_LOCAL_IP=$(hostname -i)