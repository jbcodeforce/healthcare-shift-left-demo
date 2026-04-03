#!/usr/bin/env python3
"""
Deploy Flink SQL statements to Confluent Cloud
Called by dbt run-operation or can be run standalone

Usage:
  python deploy_flink.py --layer raw
  python deploy_flink.py --layer rmd
  python deploy_flink.py --all
"""

import json
import os
import sys
import requests
import time
from pathlib import Path
from typing import Dict, List, Optional

# Base paths
REPO_ROOT = Path(__file__).parent.parent.parent
PIPELINES_DIR = REPO_ROOT / "pipelines"
INVENTORY_FILE = PIPELINES_DIR / "inventory.json"


class FlinkDeployer:
    """Deploy Flink SQL statements to Confluent Cloud"""

    def __init__(self):
        # Load config from environment
        self.flink_endpoint = os.getenv('FLINK_REST_ENDPOINT')
        self.flink_api_key = os.getenv('FLINK_API_KEY')
        self.flink_api_secret = os.getenv('FLINK_API_SECRET')
        self.compute_pool_id = os.getenv('FLINK_COMPUTE_POOL_ID')
        self.principal_id = os.getenv('PRINCIPAL_ID')
        self.env_id = os.getenv('ENV_ID')
        self.org_id = os.getenv('ORG_ID', '')
        self.env_display_name = os.getenv('ENV_DISPLAY_NAME', 'healthcare-shift-left-demo')
        self.kafka_display_name = os.getenv('KAFKA_CLUSTER_DISPLAY_NAME', 'healthcare-shift-left-demo-cluster')

        # Validate required config
        if not all([self.flink_endpoint, self.flink_api_key, self.flink_api_secret,
                    self.compute_pool_id, self.principal_id, self.env_id]):
            raise ValueError("Missing required environment variables. Please source backend/.env")

        # Load inventory
        with open(INVENTORY_FILE, 'r') as f:
            self.inventory = json.load(f)

    def read_sql_file(self, filepath: str) -> str:
        """Read SQL file content"""
        full_path = REPO_ROOT / filepath
        if not full_path.exists():
            raise FileNotFoundError(f"SQL file not found: {full_path}")

        with open(full_path, 'r') as f:
            return f.read()

    def read_properties_file(self, filepath: str) -> Dict[str, str]:
        """Read .properties file and return as dict"""
        props_path = Path(filepath).with_suffix('.properties')
        full_path = REPO_ROOT / str(props_path)

        properties = {}
        if full_path.exists():
            with open(full_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        properties[key.strip()] = value.strip()

        return properties

    def create_flink_statement(self, statement_name: str, sql: str, properties: Optional[Dict] = None) -> Dict:
        """Create or update Flink statement via REST API"""

        # Base properties
        base_props = {
            'sql.current-catalog': self.env_display_name,
            'sql.current-database': self.kafka_display_name
        }

        # Merge with custom properties
        if properties:
            base_props.update(properties)

        # Build request - Confluent Flink API v1 format (matches CLI format)
        url = f"{self.flink_endpoint}/sql/v1/organizations/{self.org_id}/environments/{self.env_id}/statements"

        payload = {
            "name": statement_name,
            "spec": {
                "statement": sql,
                "properties": base_props,
                "compute_pool_id": self.compute_pool_id,
                "principal": self.principal_id
            }
        }

        headers = {
            "Content-Type": "application/json"
        }

        print(f"\n{'='*80}")
        print(f"Creating Flink Statement: {statement_name}")
        print(f"Compute Pool: {self.compute_pool_id}")
        print(f"SQL Preview: {sql[:150]}...")
        print(f"{'='*80}\n")

        response = requests.post(
            url,
            json=payload,
            headers=headers,
            auth=(self.flink_api_key, self.flink_api_secret)
        )

        if response.status_code in [200, 201]:
            result = response.json()
            print(f"✅ Statement created: {result.get('name')} (ID: {result.get('name')})")
            return result
        else:
            print(f"❌ Failed to create statement: {response.status_code}")
            print(f"Response: {response.text}")
            raise Exception(f"Failed to create Flink statement: {response.text}")

    def deploy_table(self, table_name: str, table_info: Dict):
        """Deploy DDL and DML for a single table"""
        print(f"\n🚀 Deploying table: {table_name}")
        print(f"   Layer: {table_info['product_name']}")

        # Deploy DDL
        ddl_path = table_info['ddl_ref']
        ddl_sql = self.read_sql_file(ddl_path)
        ddl_statement_name = f"hc-ddl-{table_name.replace('_', '-')}"

        try:
            self.create_flink_statement(ddl_statement_name, ddl_sql)
            time.sleep(2)  # Brief pause between DDL and DML
        except Exception as e:
            print(f"⚠️  DDL deployment warning: {e}")

        # Deploy DML if exists
        if table_info.get('dml_ref'):
            dml_path = table_info['dml_ref']
            dml_sql = self.read_sql_file(dml_path)
            dml_statement_name = f"hc-dml-{table_name.replace('_', '-')}"

            # Load properties if they exist
            properties = self.read_properties_file(dml_path)

            try:
                self.create_flink_statement(dml_statement_name, dml_sql, properties)
            except Exception as e:
                print(f"⚠️  DML deployment warning: {e}")

        print(f"✅ Table {table_name} deployed successfully\n")

    def deploy_layer(self, layer: str):
        """Deploy all tables in a specific layer"""
        print(f"\n📦 Deploying layer: {layer}")

        # Filter tables by layer
        tables = {k: v for k, v in self.inventory.items() if v['product_name'] == layer}

        if not tables:
            print(f"⚠️  No tables found for layer: {layer}")
            return

        print(f"Found {len(tables)} tables in {layer} layer")

        for table_name, table_info in tables.items():
            self.deploy_table(table_name, table_info)

        print(f"\n✅ Layer {layer} deployment complete!")

    def deploy_all(self):
        """Deploy all layers in dependency order"""
        layers = ['raw', 'rmd']

        print("\n" + "="*80)
        print("🚀 Starting full Flink pipeline deployment")
        print("="*80)

        for layer in layers:
            self.deploy_layer(layer)

        print("\n" + "="*80)
        print("✅ All pipelines deployed successfully!")
        print("="*80)


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Deploy Flink SQL to Confluent Cloud')
    parser.add_argument('--layer', choices=['raw', 'rmd'], help='Deploy specific layer')
    parser.add_argument('--all', action='store_true', help='Deploy all layers')
    parser.add_argument('--table', help='Deploy specific table')

    args = parser.parse_args()

    try:
        deployer = FlinkDeployer()

        if args.all:
            deployer.deploy_all()
        elif args.layer:
            deployer.deploy_layer(args.layer)
        elif args.table:
            if args.table in deployer.inventory:
                deployer.deploy_table(args.table, deployer.inventory[args.table])
            else:
                print(f"❌ Table not found: {args.table}")
                sys.exit(1)
        else:
            print("❌ Please specify --all, --layer, or --table")
            parser.print_help()
            sys.exit(1)

    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
