#!/usr/bin/env bash
set -e

echo "Starting Spark Master..."

$SPARK_HOME/sbin/start-master.sh --host spark-master

# Keep container alive
tail -f /opt/spark/logs/* || sleep infinity