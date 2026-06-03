from pydantic_settings import BaseSettings, SettingsConfigDict
import os

"""
Environment-driven settings for Kafka and Schema Registry.
"""
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", env_file=".env", extra="ignore")

    # Kafka (Confluent Cloud)
    kafka_bootstrap_servers: str = ""
    kafka_sasl_username: str = os.getenv("KAFKA_API_KEY") or model_config.get("kafka_sasl_username")
    kafka_sasl_password: str = os.getenv("KAFKA_API_SECRET") or model_config.get("kafka_sasl_password")
    kafka_security_protocol: str = "SASL_SSL"
    kafka_sasl_mechanism: str = "PLAIN"
    kafka_topic: str = "hc_raw_device_metrics"
    kafka_device_events_topic: str = "hc_raw_device_events"
    kafka_device_assignments_topic: str = "hc_src_device_assignments"
    kafka_care_areas_topic: str = "hc_dim_care_areas"
    kafka_update_allowlist_topic: str = "hc_src_device_update_allowlist"

    # Schema Registry (Confluent Cloud)
    schema_registry_url: str = ""
    schema_registry_basic_auth_user_info: str = ""  # "key:secret"
    schema_subject_prefix: str = ".flink-dev"

    # Kafka consumer (hc_fct_telemetry_1h Avro via Schema Registry)
    kafka_consumer_topic: str = "hc_fct_telemetry_1h"
    kafka_consumer_group_id: str = "hc_fct_telemetry_1h-gp"
    kafka_consumer_enabled: bool = False
    kafka_consumer_auto_offset_reset: str = "earliest"
    

    # Simulation
    # Simulated narrative time between full rounds (all patients); not wall-clock sleep.
    simulation_interval_seconds: float = 300.0
    simulation_records_per_second: float = 5.0
    simulation_num_patients: int = 5
    simulation_flow_level_max: float = 130.0
    simulation_flow_level_min: float = 0.0
    simulation_flow_level_jitter: float = 100.0
    simulation_flow_level_base: float = 150.0
    simulation_backfill_days: int = 180

    # PostgreSQL (prescriptions)
    database_url: str = ""

    # Analytics (S3 Parquet / Iceberg via DuckDB)
    analytics_s3_bucket: str = ""
    analytics_s3_prefix: str = ""
    analytics_local_path: str = ""  # e.g. analytics/sample-data/parquet for local Parquet
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"


def get_settings() -> Settings:
    return Settings()
