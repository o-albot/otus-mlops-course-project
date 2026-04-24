"""
DAG #1: Feature Pipeline - Data preprocessing
Schedule: Daily
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.dummy import DummyOperator
from airflow.providers.yandex.operators.dataproc import (
    DataprocCreateClusterOperator,
    DataprocCreatePysparkJobOperator,
    DataprocDeleteClusterOperator
)
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
import os

# ========== VARIABLES ==========
# Из Airflow Variables (импортированных из variables.json)
YC_ZONE = Variable.get("YC_ZONE")
YC_FOLDER_ID = Variable.get("YC_FOLDER_ID")
YC_SUBNET_ID = Variable.get("YC_SUBNET_ID")
YC_SSH_PUBLIC_KEY = Variable.get("YC_SSH_PUBLIC_KEY")
DP_SA_ID = Variable.get("DP_SA_ID")
DP_SA_AUTH_KEY_PUBLIC_KEY = Variable.get("DP_SA_AUTH_KEY_PUBLIC_KEY")
DP_SA_JSON = Variable.get("DP_SA_JSON")
DP_SECURITY_GROUP_ID = Variable.get("DP_SECURITY_GROUP_ID")
MLFLOW_TRACKING_URI = Variable.get("MLFLOW_TRACKING_URI")

# Из Kubernetes Secret (автоматически доступны как переменные окружения)
S3_BUCKET_NAME = os.environ.get("S3_BUCKET")
S3_ENDPOINT_URL = os.environ.get("S3_ENDPOINT")

# Проверка обязательных переменных
if not S3_BUCKET_NAME:
    raise ValueError("S3_BUCKET environment variable not set. Check K8s secret.")
if not S3_ENDPOINT_URL:
    raise ValueError("S3_ENDPOINT environment variable not set. Check K8s secret.")

# Connection ID for Yandex Cloud (create in Airflow UI)
YC_SA_CONNECTION_ID = "yc_sa_connection"

# S3 Paths
S3_VENV_ARCHIVE = f"s3a://{S3_BUCKET_NAME}/venvs/venv.tar.gz"
S3_SRC_BUCKET = f"s3a://{S3_BUCKET_NAME}/src"
S3_RAW_DATA = f"s3a://{S3_BUCKET_NAME}/data/cloud_query_dataset.csv"
S3_PROCESSED_TRAIN = f"s3a://{S3_BUCKET_NAME}/processed/train.parquet"
S3_PROCESSED_TEST = f"s3a://{S3_BUCKET_NAME}/processed/test.parquet"
S3_DP_LOGS = f"s3a://{S3_BUCKET_NAME}/airflow_logs/"

# MLflow
MLFLOW_EXPERIMENT_NAME = "feature_pipeline"

# Spark properties (без явных ключей — используется IAM сервисного аккаунта)
SPARK_PROPERTIES = {
    'spark.submit.deployMode': 'cluster',
    'spark.yarn.dist.archives': f'{S3_VENV_ARCHIVE}#.venv',
    'spark.yarn.appMasterEnv.PYSPARK_PYTHON': './.venv/bin/python3',
    'spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON': './.venv/bin/python3',
    'spark.sql.adaptive.enabled': 'true',
    'spark.sql.adaptive.coalescePartitions.enabled': 'true',
    'spark.hadoop.fs.s3a.endpoint': S3_ENDPOINT_URL,
    # IAM сервисного аккаунта даёт доступ к S3, ключи не нужны
}

# ========== DAG DEFAULTS ==========
default_args = {
    'owner': 'mlops',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# ========== DAG DEFINITION ==========
dag = DAG(
    dag_id="feature_pipeline",
    default_args=default_args,
    description="Feature Pipeline: Data preprocessing for query latency prediction",
    schedule_interval=timedelta(days=1),
    catchup=False,
    max_active_runs=1,
    tags=['feature', 'preprocessing', 'mlops'],
)

# ========== TASKS ==========

start = DummyOperator(
    task_id="start",
    dag=dag,
)

create_cluster = DataprocCreateClusterOperator(
    task_id="create_dataproc_cluster",
    folder_id=YC_FOLDER_ID,
    cluster_name=f"feature-pipeline-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
    cluster_description="Temporary Dataproc cluster for feature preprocessing",
    subnet_id=YC_SUBNET_ID,
    s3_bucket=S3_DP_LOGS,
    service_account_id=DP_SA_ID,
    ssh_public_keys=YC_SSH_PUBLIC_KEY,
    zone=YC_ZONE,
    cluster_image_version="2.0",
    masternode_resource_preset="s3-c2-m8",
    masternode_disk_type="network-ssd",
    masternode_disk_size=50,
    datanode_resource_preset="s3-c4-m16",
    datanode_disk_type="network-ssd",
    datanode_disk_size=100,
    datanode_count=1,
    computenode_count=0,
    services=["YARN", "SPARK", "HDFS"],
    connection_id=YC_SA_CONNECTION_ID,
    dag=dag,
)

preprocess = DataprocCreatePysparkJobOperator(
    task_id="preprocess_data",
    main_python_file_uri=f"{S3_SRC_BUCKET}/preprocess.py",
    connection_id=YC_SA_CONNECTION_ID,
    dag=dag,
    args=[
        "--input", S3_RAW_DATA,
        "--output-train", S3_PROCESSED_TRAIN,
        "--output-test", S3_PROCESSED_TEST,
        "--tracking-uri", MLFLOW_TRACKING_URI,
        "--experiment-name", MLFLOW_EXPERIMENT_NAME,
        "--test-size", "0.2",
        "--seed", "42",
    ],
    properties=SPARK_PROPERTIES,
)

delete_cluster = DataprocDeleteClusterOperator(
    task_id="delete_dataproc_cluster",
    trigger_rule=TriggerRule.ALL_DONE,
    dag=dag,
)

end = DummyOperator(
    task_id="end",
    trigger_rule=TriggerRule.ALL_DONE,
    dag=dag,
)

# ========== DEPENDENCIES ==========
start >> create_cluster >> preprocess >> delete_cluster >> end