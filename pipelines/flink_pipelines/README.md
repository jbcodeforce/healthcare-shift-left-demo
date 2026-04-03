# Healthcare Shift-Left Demo - Flink Pipelines (dbt)

Deploy Flink SQL pipelines to Confluent Cloud using dbt for organization and dependency management.

## Overview

This dbt project provides a structured way to deploy Flink SQL statements to Confluent Cloud:

- **Organized by layer**: raw → rmd (sources, dimensions, facts)
- **Dependency management**: Ensures correct deployment order
- **Environment-based config**: Uses `.env` for Confluent credentials
- **Reuses existing SQL**: References SQL files in `../raw` and `../rmd` directories

## Prerequisites

1. **Python 3.8+** with packages:
   ```bash
   pip install -r requirements.txt
   ```
   Or install manually:
   ```bash
   pip install dbt-core dbt-postgres requests
   ```

2. **Confluent Cloud credentials** in `backend/.env`

3. **Source environment**:
   ```bash
   cd /path/to/healthcare-shift-left-demo
   source backend/.env
   ```

## Quick Start

### Deploy All Pipelines

```bash
cd pipelines/flink_pipelines
python3 deploy_flink.py --all
```

### Deploy Specific Layer

```bash
# Deploy raw layer only
python3 deploy_flink.py --layer raw

# Deploy rmd layer only
python3 deploy_flink.py --layer rmd
```

## Using dbt

### View Project Structure

```bash
dbt ls
```

### Generate Documentation

```bash
dbt docs generate
dbt docs serve
```

##See Also

- [Parent README](../../README.md)
- [Terraform Deployment](../../IaC/README.md)
