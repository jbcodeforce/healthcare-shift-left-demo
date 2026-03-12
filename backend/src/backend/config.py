from pydantic_settings import BaseSettings, SettingsConfigDict
import os


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", env_file=".env", extra="ignore")

    # Kafka (Confluent Cloud)
    kafka_bootstrap_servers: str = ""
    kafka_sasl_username: str = os.getenv("KAFKA_API_KEY") or ""
    kafka_sasl_password: str = os.getenv("KAFKA_API_SECRET") or ""
    kafka_security_protocol: str = "SASL_SSL"
    kafka_sasl_mechanism: str = "PLAIN"
    kafka_topic: str = "device_metrics"

    # Schema Registry (Confluent Cloud)
    schema_registry_url: str = ""
    schema_registry_basic_auth_user_info: str = ""
    schema_subject_prefix: str = ".flink-dev"

    # Simulation
    simulation_interval_seconds: float = 2.0
    simulation_num_patients: int = 5


def get_settings() -> Settings:
    return Settings()
