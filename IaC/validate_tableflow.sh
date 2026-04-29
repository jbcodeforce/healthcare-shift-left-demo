#!/bin/bash
# Validation script for Tableflow setup
# Checks S3 bucket, IAM role, and data flow

set -e

echo "🔍 Validating Tableflow Setup"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_DIR="${SCRIPT_DIR}/aws"

# Expect IaC/validate_tableflow.sh and IaC/aws/ (S3 is a separate Terraform root)
if [ ! -f "${AWS_DIR}/main.tf" ]; then
    echo -e "${RED}❌ Error: Expected ${AWS_DIR} (Tableflow AWS stack). Run this script from the repo IaC directory.${NC}"
    exit 1
fi

echo "📋 Step 1: Checking Terraform outputs (IaC/aws)..."
if ! terraform -chdir="${AWS_DIR}" output s3_analytics_bucket > /dev/null 2>&1; then
    echo -e "${RED}❌ Terraform outputs not available. Run: cd ${AWS_DIR} && terraform init && terraform apply${NC}"
    exit 1
fi

BUCKET_NAME=$(terraform -chdir="${AWS_DIR}" output -raw s3_analytics_bucket 2>/dev/null || echo "")
if [ -z "$BUCKET_NAME" ]; then
    echo -e "${YELLOW}⚠️  Tableflow S3 not enabled. Set enable_tableflow=true in IaC/aws/terraform.tfvars${NC}"
    exit 0
fi

echo -e "${GREEN}✅ S3 Bucket: ${BUCKET_NAME}${NC}"

echo ""
echo "📋 Step 2: Checking S3 bucket accessibility..."
if aws s3 ls "s3://${BUCKET_NAME}/" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ S3 bucket is accessible${NC}"
else
    echo -e "${RED}❌ Cannot access S3 bucket. Check AWS credentials.${NC}"
    exit 1
fi

echo ""
echo "📋 Step 3: Checking IAM role..."
ROLE_ARN=$(terraform -chdir="${AWS_DIR}" output -raw tableflow_iam_role_arn 2>/dev/null || echo "")
if [ -z "$ROLE_ARN" ]; then
    echo -e "${RED}❌ IAM role not created${NC}"
    exit 1
fi
echo -e "${GREEN}✅ IAM Role: ${ROLE_ARN}${NC}"

echo ""
echo "📋 Step 4: Checking for data in S3..."
DATA_FOUND=false

for PATH in "anomalies" "prescription_changes" "telemetries"; do
    echo -n "  Checking ${PATH}... "
    FILE_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}/${PATH}/" --recursive 2>/dev/null | wc -l || echo "0")

    if [ "$FILE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ ${FILE_COUNT} files found${NC}"
        DATA_FOUND=true
    else
        echo -e "${YELLOW}⚠️  No data yet (this is normal if Flink just started)${NC}"
    fi
done

echo ""
echo "📋 Step 5: Tableflow connections (Confluent UI)..."
echo -e "${YELLOW}  S3 and IAM are Terraform; create the three connections/sinks in the Confluent Cloud UI (see README).${NC}"

echo ""
echo "📋 Step 6: Generating backend/.env snippet..."
echo "Add these lines to backend/.env:"
echo ""
echo "# Analytics S3 Configuration (from Tableflow)"
echo "ANALYTICS_S3_BUCKET=${BUCKET_NAME}"
echo "ANALYTICS_S3_PREFIX="
REGION=$(terraform -chdir="${AWS_DIR}" output -raw s3_analytics_bucket_region 2>/dev/null || echo "us-east-2")
echo "AWS_REGION=${REGION}"
echo ""

echo "📋 Step 7: Testing DuckDB S3 access (optional)..."
if command -v python3 &> /dev/null; then
    echo -n "  Checking if DuckDB can access S3... "

    # Create a simple Python script to test DuckDB S3 access
    cat > /tmp/test_duckdb_s3.py << 'EOF'
import sys
import duckdb

bucket = sys.argv[1] if len(sys.argv) > 1 else ""
if not bucket:
    print("❌ No bucket provided")
    sys.exit(1)

try:
    conn = duckdb.connect(":memory:")
    conn.execute("INSTALL httpfs")
    conn.execute("LOAD httpfs")

    # Try to list files (read-only test)
    result = conn.execute(f"SELECT count(*) FROM read_parquet('s3://{bucket}/anomalies/*.parquet') LIMIT 1").fetchone()
    print(f"✅ DuckDB can access S3 (found data: {result is not None})")
except Exception as e:
    if "No files found" in str(e):
        print("⚠️  DuckDB can access S3, but no data files yet")
    else:
        print(f"❌ DuckDB S3 access failed: {e}")
        sys.exit(1)
EOF

    python3 /tmp/test_duckdb_s3.py "$BUCKET_NAME" 2>/dev/null || echo -e "${YELLOW}⚠️  DuckDB test skipped (install duckdb package to test)${NC}"
    rm -f /tmp/test_duckdb_s3.py
else
    echo -e "${YELLOW}⚠️  Python3 not found, skipping DuckDB test${NC}"
fi

echo ""
echo "=============================="
echo -e "${GREEN}🎉 Validation Complete!${NC}"
echo ""

if [ "$DATA_FOUND" = true ]; then
    echo "✅ Tableflow is working! Data is flowing to S3."
    echo ""
    echo "Next steps:"
    echo "1. Update backend/.env with the configuration above"
    echo "2. Restart backend: docker compose restart backend"
    echo "3. Check analytics dashboard: http://localhost:5173/analytics"
else
    echo "⚠️  Setup looks good, but no data in S3 yet."
    echo ""
    echo "This is normal if:"
    echo "- Flink pipelines were just deployed"
    echo "- Tableflow sinks are still starting"
    echo "- No data has been processed yet"
    echo ""
    echo "Check Confluent UI: Environment → Tableflow → Sinks"
    echo "Expected status: Running (may take a few minutes)"
fi

echo ""
echo "For troubleshooting, see: IaC/README.md (Tableflow and S3)"
