#!/usr/bin/env bash
set -e

echo "Starting Spark Thrift Server..."

if [ -z "$SPARK_MASTER_URL" ]; then
  export SPARK_MASTER_URL="spark://spark-master:7077"
fi

$SPARK_HOME/sbin/start-thriftserver.sh \
  --master $SPARK_MASTER_URL \
  --hiveconf hive.server2.thrift.port=10000 \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0

tail -f /opt/spark/logs/* || sleep infinity