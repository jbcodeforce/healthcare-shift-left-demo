#!/usr/bin/env python3
"""
End-to-end dbt → Flink deploy:

1. `dbt compile` — builds the DAG and fills `compiled_code` on each model in target/manifest.json
2. Confluent Flink REST API — submits each compiled statement in `deploy_sequence` order

Regenerate models when inventory changes:

  python3 generate_flink_models.py

Usage:
  cd pipelines/flink_pipelines
  source ../../backend/.env
  python3 dbt_flink_deploy.py --all
  python3 dbt_flink_deploy.py --layer rmd
  python3 dbt_flink_deploy.py --table hc_raw_patients
  python3 dbt_flink_deploy.py --legacy-inventory --all   # skip dbt; read SQL files from inventory only
  python3 dbt_flink_deploy.py --skip-dbt-compile --all    # use existing target/manifest.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = PROJECT_DIR / "target" / "manifest.json"


def run_dbt_compile() -> None:
    from dbt.cli.main import dbtRunner

    dbt = dbtRunner()
    result = dbt.invoke(
        [
            "compile",
            "--project-dir",
            str(PROJECT_DIR),
            "--profiles-dir",
            str(PROJECT_DIR),
        ]
    )
    if not result.success:
        err = result.exception
        raise RuntimeError(str(err) if err else "dbt compile failed")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="dbt compile + deploy Flink statements from manifest (or legacy inventory)"
    )
    parser.add_argument(
        "--skip-dbt-compile",
        action="store_true",
        help="Do not run dbt compile; use existing target/manifest.json",
    )
    parser.add_argument(
        "--legacy-inventory",
        action="store_true",
        help="Skip dbt entirely; deploy SQL files listed in pipelines/inventory.json",
    )
    parser.add_argument(
        "--skip-dbt-parse",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--layer", choices=["raw", "rmd"], help="Deploy one medallion layer")
    parser.add_argument("--all", action="store_true", help="Deploy all layers / all statements")
    parser.add_argument("--table", help="Deploy DDL+DML for one inventory table key")

    args = parser.parse_args()
    if args.skip_dbt_parse:
        args.skip_dbt_compile = True

    if args.legacy_inventory:
        from flink_deployer import FlinkDeployer

        try:
            deployer = FlinkDeployer()
        except Exception as e:
            print(f"❌ {e}")
            sys.exit(1)
        if args.all:
            deployer.deploy_all()
        elif args.layer:
            deployer.deploy_layer(args.layer)
        elif args.table:
            if args.table not in deployer.inventory:
                print(f"❌ Table not in inventory: {args.table}")
                sys.exit(1)
            deployer.deploy_table(args.table, deployer.inventory[args.table])
        else:
            parser.error("With --legacy-inventory, specify --all, --layer, or --table")
        return

    if not args.skip_dbt_compile:
        print("Running dbt compile...", flush=True)
        try:
            run_dbt_compile()
        except Exception as e:
            print(f"dbt compile failed: {e}")
            sys.exit(1)
        print("dbt compile OK.\n", flush=True)

    if not MANIFEST_PATH.is_file():
        print(f"❌ Missing {MANIFEST_PATH}. Run dbt compile first.")
        sys.exit(1)

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    from flink_deployer import FlinkDeployer

    try:
        deployer = FlinkDeployer()
    except Exception as e:
        print(f"❌ {e}")
        sys.exit(1)

    try:
        if args.all:
            deployer.deploy_from_manifest(manifest)
        elif args.layer:
            deployer.deploy_from_manifest(manifest, layer=args.layer)
        elif args.table:
            deployer.deploy_from_manifest(manifest, table=args.table)
        else:
            parser.error("Specify --all, --layer, or --table")
    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
