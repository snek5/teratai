# cosmos/dags/init_iceberg_tables_dynamic.py
"""
Dynamic DAG that creates a SparkSubmit task for EACH table in sources.yml.
This gives you per-table visibility and retry capability.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import PythonOperator
import yaml
import os

default_args = {
    'owner': 'data_team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

SPARK_CONN_ID = 'spark_default'
SOURCES_YML = '/app/dbt/teratai/models/sources/sources.yml'
SCRIPT_PATH = '/app/scripts/init_iceberg_from_dbt_sources.py'

SPARK_CONF = {
    'packages': 'org.apache.iceberg:iceberg-spark-runtime-3.4_2.12:1.5.2,org.apache.hadoop:hadoop-aws:3.3.4',
    'conf': {
        'spark.sql.adaptive.enabled': 'true',
        'spark.dynamicAllocation.enabled': 'true',
        'spark.dynamicAllocation.minExecutors': '1',
        'spark.dynamicAllocation.maxExecutors': '4'
    }
}

def parse_sources():
    """Parse sources.yml and return table names"""
    with open(SOURCES_YML, 'r') as f:
        config = yaml.safe_load(f)
    
    tables = []
    for source in config.get('sources', []):
        for table in source.get('tables', []):
            tables.append(table['name'])
    return tables

# Get table names
TABLES = parse_sources()

dag = DAG(
    'init_iceberg_tables_dynamic',
    default_args=default_args,
    description='Dynamically initialize Iceberg tables from dbt sources',
    schedule_interval=None,
    catchup=False,
    tags=['iceberg', 'dbt', 'dynamic'],
)

start = DummyOperator(task_id='start', dag=dag)

# Dynamically create tasks for each table
init_tasks = []
for table_name in TABLES:
    task_id = f"init_{table_name}"
    
    init_task = SparkSubmitOperator(
        task_id=task_id,
        application=SCRIPT_PATH,
        conn_id=SPARK_CONN_ID,
        application_args=[
            '--sources-yml', SOURCES_YML,
            '--catalog-name', 'iceberg',
            '--target-db', 'staging',
            '--table-filter', table_name,
            '--partition-by', 'year', 'month', 'day'
        ],
        **SPARK_CONF,
        dag=dag,
    )
    init_tasks.append(init_task)

# Run dbt after all tables are initialized
run_dbt = BashOperator(
    task_id='run_dbt',
    bash_command=f"cd /app/dbt/teratai && dbt run",
    dag=dag,
)

end = DummyOperator(task_id='end', dag=dag)

# Dependencies
start >> init_tasks >> run_dbt >> end