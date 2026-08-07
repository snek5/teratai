# cosmos/dags/init_iceberg_dag.py
"""
Dynamic DAG that creates Iceberg tables using Spark Thrift Server
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_sql import SparkSqlOperator
from airflow.operators.empty import EmptyOperator
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

# Connection ID for Spark Thrift Server
SPARK_THRIFT_CONN_ID = 'spark_thrift_default'
SOURCES_YML = '/app/dbt/teratai/models/sources/sources.yml'

def parse_sources():
    """Parse sources.yml and return table names with their configs"""
    try:
        with open(SOURCES_YML, 'r') as f:
            config = yaml.safe_load(f)
        
        tables = []
        for source in config.get('sources', []):
            # Get source name and path info
            source_name = source.get('name', 'unknown')
            source_path = source.get('path', '')
            
            for table in source.get('tables', []):
                tables.append({
                    'name': table['name'],
                    'source_name': source_name,
                    'source_path': source_path,
                    'partition_cols': table.get('partition_by', ['year', 'month', 'day']),
                    # Get any other metadata from sources.yml
                    'format': table.get('format', 'csv'),
                    'delimiter': table.get('delimiter', ','),
                    'header': table.get('header', True),
                })
        return tables
    except FileNotFoundError:
        print(f"⚠️ sources.yml not found at {SOURCES_YML}")
        return []
    except Exception as e:
        print(f"⚠️ Error parsing sources.yml: {e}")
        return []

# Get table configurations
TABLES = parse_sources()
print(f"📋 Found tables: {[t['name'] for t in TABLES]}")

# Create DAG
dag = DAG(
    'init_iceberg_tables_thrift',
    default_args=default_args,
    description='Initialize Iceberg tables via Spark Thrift Server',
    schedule=None,
    catchup=False,
    tags=['iceberg', 'spark', 'thrift', 'airflow3'],
)

# Start and End operators
start = EmptyOperator(task_id='start', dag=dag)
end = EmptyOperator(task_id='end', dag=dag)

# Create tasks for each table
init_tasks = []
if TABLES:
    for table_config in TABLES:
        table_name = table_config['name']
        task_id = f"init_{table_name}"
        partition_cols = table_config['partition_cols']
        
        # Build the CREATE TABLE SQL
        # Note: Adjust the CSV path based on your data location
        csv_path = f"/data/sources/{table_name}"  # Adjust this path!
        
        # SQL to create Iceberg table from CSV
        create_table_sql = f"""
        -- Create Iceberg table if not exists
        CREATE TABLE IF NOT EXISTS iceberg.staging.stg_{table_name}
        USING iceberg
        PARTITIONED BY ({', '.join(partition_cols)})
        AS 
        SELECT * FROM csv.`{csv_path}`
        """
        
        # Alternative: Create table without data, then insert
        create_empty_sql = f"""
        -- Create empty Iceberg table
        CREATE TABLE IF NOT EXISTS iceberg.staging.stg_{table_name} (
            -- Add your column definitions here
            -- This is optional - Spark can infer schema from CSV
        )
        USING iceberg
        PARTITIONED BY ({', '.join(partition_cols)})
        """
        
        # Insert data into existing table
        insert_sql = f"""
        -- Insert data into existing table (overwrite or append)
        INSERT OVERWRITE iceberg.staging.stg_{table_name}
        SELECT * FROM csv.`{csv_path}`
        """
        
        # For simplicity, we'll use a single SQL that creates and populates
        init_task = SparkSqlOperator(
            task_id=task_id,
            conn_id=SPARK_THRIFT_CONN_ID,
            sql=create_table_sql,
            dag=dag,
        )
        
        # Add documentation
        init_task.doc_md = f"""
        ### Initialize Table: {table_name}
        
        - **Source:** CSV from `{csv_path}`
        - **Target:** `iceberg.staging.stg_{table_name}`
        - **Partitions:** {', '.join(partition_cols)}
        - **Method:** CREATE TABLE ... AS SELECT
        """
        
        init_tasks.append(init_task)

# Define dependencies
if init_tasks:
    start >> init_tasks >> end
else:
    start >> end