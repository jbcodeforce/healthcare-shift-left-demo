"""
Deploy Flink SQL statements to Confluent Cloud via REST API.
Shared by deploy_flink.py (CLI) and dbt_flink_deploy.py (dbt parse + deploy).
"""

import json
import os
import time
from pathlib import Path
from typing import Dict, Optional

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
PIPELINES_DIR = REPO_ROOT / "pipelines"
INVENTORY_FILE = PIPELINES_DIR / "inventory.json"


class FlinkDeployer:
    """Deploy Flink SQL statements to Confluent Cloud"""

    def __init__(self):
        self.flink_endpoint = os.getenv("FLINK_REST_ENDPOINT")
        self.flink_api_key = os.getenv("FLINK_API_KEY")
        self.flink_api_secret = os.getenv("FLINK_API_SECRET")
        self.compute_pool_id = os.getenv("FLINK_COMPUTE_POOL_ID")
        self.principal_id = os.getenv("PRINCIPAL_ID")
        self.env_id = os.getenv("ENV_ID")
        self.org_id = os.getenv("ORG_ID") or os.getenv("FLINK_ORG_ID", "")
        self.env_display_name = os.getenv("ENV_DISPLAY_NAME", "healthcare-shift-left-demo")
        self.kafka_display_name = os.getenv(
            "KAFKA_CLUSTER_DISPLAY_NAME", "healthcare-shift-left-demo-cluster"
        )

        if not all(
            [
                self.flink_endpoint,
                self.flink_api_key,
                self.flink_api_secret,
                self.compute_pool_id,
                self.principal_id,
                self.env_id,
            ]
        ):
            raise ValueError("Missing required environment variables. Please source backend/.env")

        if not self.org_id:
            raise ValueError(
                "ORG_ID is required for Flink REST API paths. Set it in backend/.env "
                "(Confluent Cloud organization ID)."
            )

        with open(INVENTORY_FILE, "r") as f:
            self.inventory = json.load(f)

    def read_sql_file(self, filepath: str) -> str:
        full_path = REPO_ROOT / filepath
        if not full_path.exists():
            raise FileNotFoundError(f"SQL file not found: {full_path}")
        with open(full_path, "r") as f:
            return f.read()

    def read_properties_file(self, filepath: str) -> Dict[str, str]:
        props_path = Path(filepath).with_suffix(".properties")
        full_path = REPO_ROOT / str(props_path)
        properties: Dict[str, str] = {}
        if full_path.exists():
            with open(full_path, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        key, value = line.split("=", 1)
                        properties[key.strip()] = value.strip()
        return properties

    def create_flink_statement(
        self, statement_name: str, sql: str, properties: Optional[Dict] = None
    ) -> Dict:
        base_props = {
            "sql.current-catalog": self.env_display_name,
            "sql.current-database": self.kafka_display_name,
        }
        if properties:
            base_props.update(properties)

        url = (
            f"{self.flink_endpoint}/sql/v1/organizations/{self.org_id}"
            f"/environments/{self.env_id}/statements"
        )
        payload = {
            "name": statement_name,
            "spec": {
                "statement": sql,
                "properties": base_props,
                "compute_pool_id": self.compute_pool_id,
                "principal": self.principal_id,
            },
        }

        print(f"\n{'='*80}")
        print(f"Creating Flink Statement: {statement_name}")
        print(f"Compute Pool: {self.compute_pool_id}")
        print(f"SQL Preview: {sql[:150]}...")
        print(f"{'='*80}\n")

        response = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            auth=(self.flink_api_key, self.flink_api_secret),
        )

        if response.status_code in [200, 201]:
            result = response.json()
            print(f"✅ Statement created: {result.get('name')} (ID: {result.get('name')})")
            return result
        print(f"❌ Failed to create statement: {response.status_code}")
        print(f"Response: {response.text}")
        raise RuntimeError(f"Failed to create Flink statement: {response.text}")

    def deploy_table(self, table_name: str, table_info: Dict):
        print(f"\n🚀 Deploying table: {table_name}")
        print(f"   Layer: {table_info['product_name']}")

        ddl_path = table_info["ddl_ref"]
        ddl_sql = self.read_sql_file(ddl_path)
        ddl_statement_name = f"hc-ddl-{table_name.replace('_', '-')}"

        try:
            self.create_flink_statement(ddl_statement_name, ddl_sql)
            time.sleep(2)
        except Exception as e:
            print(f"⚠️  DDL deployment warning: {e}")

        if table_info.get("dml_ref"):
            dml_path = table_info["dml_ref"]
            dml_sql = self.read_sql_file(dml_path)
            dml_statement_name = f"hc-dml-{table_name.replace('_', '-')}"
            properties = self.read_properties_file(dml_path)
            try:
                self.create_flink_statement(dml_statement_name, dml_sql, properties)
            except Exception as e:
                print(f"⚠️  DML deployment warning: {e}")

        print(f"✅ Table {table_name} deployed successfully\n")

    def deploy_layer(self, layer: str):
        print(f"\n📦 Deploying layer: {layer}")
        tables = {k: v for k, v in self.inventory.items() if v["product_name"] == layer}
        if not tables:
            print(f"⚠️  No tables found for layer: {layer}")
            return
        print(f"Found {len(tables)} tables in {layer} layer")
        for table_name, table_info in tables.items():
            self.deploy_table(table_name, table_info)
        print(f"\n✅ Layer {layer} deployment complete!")

    def deploy_all(self):
        layers = ["raw", "rmd"]
        print("\n" + "=" * 80)
        print("🚀 Starting full Flink pipeline deployment")
        print("=" * 80)
        for layer in layers:
            self.deploy_layer(layer)
        print("\n" + "=" * 80)
        print("✅ All pipelines deployed successfully!")
        print("=" * 80)

    def deploy_from_manifest(
        self,
        manifest: dict,
        *,
        layer: Optional[str] = None,
        table: Optional[str] = None,
    ) -> None:
        """Deploy using compiled SQL from dbt manifest (after `dbt compile`)."""
        candidates = []
        for uid, node in manifest.get("nodes", {}).items():
            if node.get("resource_type") != "model":
                continue
            tags = node.get("tags") or []
            if "flink" not in tags:
                continue
            meta = node.get("meta") or {}
            if not meta.get("flink"):
                continue
            inv_key = meta.get("inventory_key")
            if not inv_key:
                continue
            if layer and meta.get("layer") != layer:
                continue
            if table and inv_key != table:
                continue
            seq = meta.get("deploy_sequence")
            if seq is None:
                continue
            compiled = (node.get("compiled_code") or "").strip()
            if not compiled:
                raise ValueError(
                    f"No compiled_code for {uid}; run `dbt compile` in pipelines/flink_pipelines."
                )
            stmt = meta.get("statement_name")
            if not stmt:
                raise ValueError(f"Missing statement_name in meta for {uid}")
            kind = meta.get("statement_kind")
            dml_ref = meta.get("dml_ref")
            candidates.append((seq, kind, stmt, compiled, dml_ref))

        candidates.sort(key=lambda x: x[0])
        if not candidates:
            raise ValueError(
                "No flink models in manifest. Run: python3 generate_flink_models.py && dbt compile"
            )

        print("\n" + "=" * 80)
        print("🚀 Deploying from dbt manifest (compiled models)")
        print("=" * 80)

        for _seq, kind, stmt, sql, dml_ref in candidates:
            props = None
            if kind == "dml" and dml_ref:
                props = self.read_properties_file(dml_ref)
            try:
                self.create_flink_statement(stmt, sql, props)
                if kind == "ddl":
                    time.sleep(2)
            except Exception as e:
                print(f"⚠️  Statement warning ({stmt}): {e}")

        print("\n" + "=" * 80)
        print("✅ dbt manifest deployment finished")
        print("=" * 80)
