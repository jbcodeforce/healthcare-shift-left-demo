#!/bin/bash
# Interactive Terraform Configuration Setup
# Helps you create terraform.tfvars with the right values

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
CONFLUENT_API_KEY=""
CONFLUENT_API_SECRET=""
ENVIRONMENT_ID=""
KAFKA_CLUSTER_ID=""
CLOUD_PROVIDER=""
CLOUD_REGION=""
PREFIX="health"
ENABLE_TABLEFLOW="false"
CONFLUENT_EXTERNAL_ID=""

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Welcome
clear
print_header "Healthcare Shift-Left Demo - Configuration Setup"

echo "This interactive script will help you create terraform.tfvars"
echo "with the correct values for your Confluent Cloud environment."
echo ""
print_info "You'll need:"
echo "  • Confluent Cloud API Key & Secret"
echo "  • Environment ID (or we'll create new)"
echo "  • Kafka Cluster ID (or we'll create new)"
echo ""
read -p "Press Enter to continue..."

# Step 1: Confluent Cloud API Credentials
print_header "Step 1: Confluent Cloud API Credentials"

print_info "Get these from: Confluent Cloud UI → Cloud API Keys"
print_warning "Requires: OrganizationAdmin or EnvironmentAdmin role"
echo ""

read -p "Confluent Cloud API Key: " CONFLUENT_API_KEY
read -sp "Confluent Cloud API Secret (hidden): " CONFLUENT_API_SECRET
echo ""

if [ -z "$CONFLUENT_API_KEY" ] || [ -z "$CONFLUENT_API_SECRET" ]; then
    print_error "API credentials are required!"
    exit 1
fi

print_success "API credentials saved"

# Step 2: Infrastructure Choice
print_header "Step 2: Infrastructure Setup"

echo "Do you want to:"
echo "  1) Use existing Confluent Cloud environment and Kafka cluster (Recommended)"
echo "  2) Create new environment and Kafka cluster"
echo ""
read -p "Enter choice (1 or 2): " INFRA_CHOICE

if [ "$INFRA_CHOICE" = "1" ]; then
    # Use existing infrastructure
    print_info "You'll need Environment ID and Kafka Cluster ID"
    echo ""

    read -p "Environment ID (e.g., env-xxxxx): " ENVIRONMENT_ID
    read -p "Kafka Cluster ID (e.g., lkc-xxxxx): " KAFKA_CLUSTER_ID

    if [ -z "$ENVIRONMENT_ID" ] || [ -z "$KAFKA_CLUSTER_ID" ]; then
        print_error "Environment ID and Cluster ID are required!"
        exit 1
    fi

    print_success "Will use existing infrastructure"
else
    # Create new infrastructure
    print_warning "Terraform will create new environment and Kafka cluster"
    print_info "This may take 10-15 minutes and incur costs"

    ENVIRONMENT_ID=""
    KAFKA_CLUSTER_ID=""

    print_success "Will create new infrastructure"
fi

# Step 3: Cloud Configuration
print_header "Step 3: Cloud Configuration"

if [ -n "$KAFKA_CLUSTER_ID" ]; then
    print_warning "Cloud provider and region MUST match your existing Kafka cluster!"
fi

echo ""
echo "Cloud Providers:"
echo "  1) AWS"
echo "  2) GCP"
echo "  3) AZURE"
read -p "Enter choice (1, 2, or 3): " CLOUD_CHOICE

case $CLOUD_CHOICE in
    1)
        CLOUD_PROVIDER="AWS"
        print_info "Common AWS regions: us-east-1, us-east-2, us-west-2, eu-west-1"
        read -p "AWS Region (e.g., us-east-2): " CLOUD_REGION
        ;;
    2)
        CLOUD_PROVIDER="GCP"
        print_info "Common GCP regions: us-central1, us-east1, europe-west1"
        read -p "GCP Region: " CLOUD_REGION
        ;;
    3)
        CLOUD_PROVIDER="AZURE"
        print_info "Common Azure regions: eastus, westus2, westeurope"
        read -p "Azure Region: " CLOUD_REGION
        ;;
    *)
        print_error "Invalid choice!"
        exit 1
        ;;
esac

if [ -z "$CLOUD_REGION" ]; then
    print_error "Cloud region is required!"
    exit 1
fi

print_success "Cloud configuration: $CLOUD_PROVIDER / $CLOUD_REGION"

# Step 4: Resource Naming
print_header "Step 4: Resource Naming"

read -p "Resource name prefix (default: health): " PREFIX_INPUT
if [ -n "$PREFIX_INPUT" ]; then
    PREFIX="$PREFIX_INPUT"
fi

print_success "Resources will be named: ${PREFIX}-*"

# Step 5: Tableflow (Optional)
print_header "Step 5: Tableflow Configuration (Optional)"

print_info "Tableflow writes Flink data to S3 for analytics"
print_warning "Requires External ID from Confluent and AWS credentials"
echo ""
read -p "Enable Tableflow now? (y/n): " ENABLE_TABLEFLOW_INPUT

if [[ "$ENABLE_TABLEFLOW_INPUT" =~ ^[Yy]$ ]]; then
    ENABLE_TABLEFLOW="true"

    print_info "Get External ID from:"
    echo "  • Confluent Cloud UI → Environment → Settings → Tableflow"
    echo "  • OR contact Confluent Support"
    echo ""
    read -p "Confluent External ID (leave empty to configure later): " CONFLUENT_EXTERNAL_ID

    if [ -n "$CONFLUENT_EXTERNAL_ID" ]; then
        print_success "Tableflow will be enabled with External ID"
    else
        print_warning "You can add External ID later in terraform.tfvars"
    fi
else
    ENABLE_TABLEFLOW="false"
    print_info "Tableflow disabled (can enable later)"
fi

# Generate terraform.tfvars
print_header "Step 6: Generating Configuration"

cat > terraform.tfvars << EOF
# Healthcare Shift-Left Demo - Terraform Configuration
# Generated by setup_config.sh on $(date)

# ============================================================================
# Confluent Cloud API Credentials
# ============================================================================

confluent_cloud_api_key    = "$CONFLUENT_API_KEY"
confluent_cloud_api_secret = "$CONFLUENT_API_SECRET"

# ============================================================================
# Infrastructure Configuration
# ============================================================================
EOF

if [ -n "$ENVIRONMENT_ID" ]; then
    cat >> terraform.tfvars << EOF

# Using existing infrastructure
environment_id   = "$ENVIRONMENT_ID"
kafka_cluster_id = "$KAFKA_CLUSTER_ID"
EOF
else
    cat >> terraform.tfvars << EOF

# Terraform will create new environment and cluster
# environment_id   = null
# kafka_cluster_id = null
EOF
fi

cat >> terraform.tfvars << EOF

# ============================================================================
# Cloud Configuration
# ============================================================================

cloud_provider = "$CLOUD_PROVIDER"
cloud_region   = "$CLOUD_REGION"
prefix         = "$PREFIX"

# ============================================================================
# Flink Configuration
# ============================================================================

flink_compute_pool_name    = "healthcare-demo-pool"
flink_compute_pool_max_cfu = 5

# Deploy Flink statements via Python script (not Terraform)
deploy_flink_statements = false
statement_name_prefix   = "hc"

# ============================================================================
# Tableflow Configuration (Optional)
# ============================================================================

enable_tableflow = $ENABLE_TABLEFLOW
EOF

if [ -n "$CONFLUENT_EXTERNAL_ID" ]; then
    cat >> terraform.tfvars << EOF
confluent_external_id = "$CONFLUENT_EXTERNAL_ID"
EOF
else
    cat >> terraform.tfvars << EOF
confluent_external_id = ""  # Add External ID here when ready
EOF
fi

cat >> terraform.tfvars << EOF

# ============================================================================
# Generated Configuration Summary
# ============================================================================
#
# Cloud: $CLOUD_PROVIDER / $CLOUD_REGION
EOF

if [ -n "$ENVIRONMENT_ID" ]; then
    cat >> terraform.tfvars << EOF
# Using Existing: env=$ENVIRONMENT_ID, cluster=$KAFKA_CLUSTER_ID
EOF
else
    cat >> terraform.tfvars << EOF
# Will Create: New environment and Kafka cluster
EOF
fi

cat >> terraform.tfvars << EOF
# Tableflow: $ENABLE_TABLEFLOW
#
# Next Steps:
# 1. Review: cat terraform.tfvars
# 2. Validate: terraform validate
# 3. Plan: terraform plan
# 4. Deploy: terraform apply
#    OR: ../deploy.sh
# ============================================================================
EOF

print_success "terraform.tfvars created successfully!"

# Summary
print_header "Configuration Summary"

echo -e "${CYAN}Cloud:${NC} $CLOUD_PROVIDER / $CLOUD_REGION"
echo -e "${CYAN}Prefix:${NC} $PREFIX"

if [ -n "$ENVIRONMENT_ID" ]; then
    echo -e "${CYAN}Infrastructure:${NC} Using existing (env: $ENVIRONMENT_ID)"
else
    echo -e "${CYAN}Infrastructure:${NC} Will create new"
fi

echo -e "${CYAN}Tableflow:${NC} $ENABLE_TABLEFLOW"

if [ "$ENABLE_TABLEFLOW" = "true" ] && [ -z "$CONFLUENT_EXTERNAL_ID" ]; then
    echo ""
    print_warning "Don't forget to add External ID to terraform.tfvars!"
fi

# Next steps
print_header "Next Steps"

echo "1. Review the configuration:"
echo -e "   ${CYAN}cat terraform.tfvars${NC}"
echo ""
echo "2. Validate Terraform configuration:"
echo -e "   ${CYAN}terraform init${NC}"
echo -e "   ${CYAN}terraform validate${NC}"
echo ""
echo "3. Preview changes:"
echo -e "   ${CYAN}terraform plan${NC}"
echo ""
echo "4. Deploy infrastructure:"
echo -e "   ${CYAN}terraform apply${NC}"
echo ""
echo "   OR use the automated deployment script:"
echo -e "   ${CYAN}cd .. && ./deploy.sh${NC}"
echo ""

print_success "Setup complete!"
print_info "Configuration saved to: terraform.tfvars"
