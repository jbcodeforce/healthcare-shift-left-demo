#!/usr/bin/env python3
"""
Deploy Flink SQL statements to Confluent Cloud (standalone CLI).

For the full dbt pipeline (compile → manifest → REST), use:
  python3 dbt_flink_deploy.py --all

Inventory-only (same REST calls, no dbt):
  python3 dbt_flink_deploy.py --legacy-inventory --all

Usage:
  python deploy_flink.py --layer raw
  python deploy_flink.py --layer rmd
  python deploy_flink.py --all
"""

import argparse
import sys

from flink_deployer import FlinkDeployer


def main():
    parser = argparse.ArgumentParser(description="Deploy Flink SQL to Confluent Cloud")
    parser.add_argument("--layer", choices=["raw", "rmd"], help="Deploy specific layer")
    parser.add_argument("--all", action="store_true", help="Deploy all layers")
    parser.add_argument("--table", help="Deploy specific table")

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
