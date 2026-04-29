#!/bin/bash
# Automated Deployment Script for Healthcare Shift-Left Demo
# Usage: ./deploy.sh [OPTIONS]

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKIP_TERRAFORM=false
SKIP_FLINK=false
SKIP_DOCKER=false
AUTO_APPROVE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --skip-flink)
            SKIP_FLINK=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: ./deploy.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-terraform    Skip Terraform infrastructure deployment"
            echo "  --skip-flink        Skip Flink pipeline deployment"
            echo "  --skip-docker       Skip Docker services deployment"
            echo "  --auto-approve      Auto-approve all prompts (use with caution)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Example:"
            echo "  ./deploy.sh                        # Full deployment with prompts"
            echo "  ./deploy.sh --skip-terraform       # Skip infrastructure, deploy Flink and Docker"
            echo "  ./deploy.sh --auto-approve         # Fully automated deployment"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

prompt_continue() {
    if [ "$AUTO_APPROVE" = false ]; then
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user"
            exit 0
        fi
    fi
}

# Main deployment script
print_header "Healthcare Shift-Left Demo - Automated Deployment"

print_info "This script will deploy the complete healthcare demo infrastructure."
print_info "Estimated time: 30-45 minutes"
echo ""

# Check prerequisites
print_header "Phase 0: Prerequisites Check"

print_info "Checking required software..."
check_command docker
check_command terraform
check_command python3
check_command curl
check_command jq

# Check Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_success "All prerequisites met!"

# Phase 1: Terraform Infrastructure
if [ "$SKIP_TERRAFORM" = false ]; then
    print_header "Phase 1: Infrastructure Deployment (Terraform)"

    cd IaC

    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found!"
        print_info "Please create IaC/terraform.tfvars with your Confluent Cloud credentials"
        print_info "See IaC/terraform.tfvars.example for reference"
        exit 1
    fi

    print_info "Initializing Terraform..."
    terraform init -upgrade

    print_info "Planning infrastructure changes..."
    terraform plan -out=tfplan

    echo ""
    print_warning "About to deploy infrastructure to Confluent Cloud"
    prompt_continue

    print_info "Applying Terraform configuration..."
    terraform apply tfplan
    rm tfplan

    print_info "Exporting credentials to backend/.env..."
    terraform output -raw backend_env_snippet > ../backend/.env.terraform

    # Merge or create backend/.env
    if [ -f "../backend/.env" ]; then
        # Backup existing .env
        cp ../backend/.env ../backend/.env.backup
        cat ../backend/.env.terraform >> ../backend/.env
        print_success "Credentials appended to backend/.env (backup saved as .env.backup)"
    else
        mv ../backend/.env.terraform ../backend/.env
        print_success "Created backend/.env with infrastructure credentials"
    fi

    cd ..
    print_success "Phase 1 Complete: Infrastructure deployed!"
else
    print_warning "Skipping Terraform deployment (--skip-terraform)"
fi

# Phase 2: Flink Pipelines
if [ "$SKIP_FLINK" = false ]; then
    print_header "Phase 2: Flink Pipelines Deployment"

    cd pipelines/flink_pipelines

    # Check if requests module is installed
    if ! python3 -c "import requests" &> /dev/null; then
        print_info "Installing Python dependencies..."
        pip install requests
    fi

    print_info "Sourcing environment variables..."
    if [ ! -f "../../backend/.env" ]; then
        print_error "backend/.env not found! Please complete Phase 1 first."
        exit 1
    fi

    set -a
    source ../../backend/.env
    set +a

    print_info "Verifying Flink configuration..."
    python3 -c "
import os
import sys
required = ['FLINK_REST_ENDPOINT', 'FLINK_API_KEY', 'FLINK_API_SECRET',
            'FLINK_COMPUTE_POOL_ID', 'ENV_ID', 'PRINCIPAL_ID']
missing = [v for v in required if not os.getenv(v)]
if missing:
    print(f'Missing environment variables: {missing}')
    sys.exit(1)
print('✅ All Flink environment variables are set')
"

    if [ $? -ne 0 ]; then
        print_error "Flink configuration incomplete. Check backend/.env"
        exit 1
    fi

    echo ""
    print_warning "About to deploy Flink SQL pipelines to Confluent Cloud"
    print_info "This will create tables and start data processing"
    prompt_continue

    print_info "Deploying Flink pipelines (this may take 5-10 minutes)..."
    python3 deploy_flink.py --all

    cd ../..
    print_success "Phase 2 Complete: Flink pipelines deployed!"
else
    print_warning "Skipping Flink deployment (--skip-flink)"
fi

# Phase 3: Docker Services
if [ "$SKIP_DOCKER" = false ]; then
    print_header "Phase 3: Backend & Frontend Deployment (Docker)"

    print_info "Starting Docker services..."
    docker compose up -d backend frontend postgres

    print_info "Waiting for services to start..."
    sleep 10

    # Check service health
    print_info "Checking service health..."

    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_success "Backend is healthy!"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -n "."
        sleep 2
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Backend failed to start. Check logs: docker compose logs backend"
        exit 1
    fi

    echo ""
    print_info "Starting device simulation..."
    RESPONSE=$(curl -s -X POST http://localhost:8000/simulation/start \
        -H "Content-Type: application/json" \
        -d '{"simulation_type": "all"}')

    if echo "$RESPONSE" | grep -q "started"; then
        print_success "Device simulation started!"
    else
        print_warning "Simulation may already be running or failed to start"
        echo "$RESPONSE"
    fi

    print_success "Phase 3 Complete: Application is running!"
else
    print_warning "Skipping Docker deployment (--skip-docker)"
fi

# Phase 4: Verification
print_header "Phase 4: Deployment Verification"

print_info "Running system checks..."

# Check Docker services
echo ""
print_info "Docker Services:"
docker compose ps

# Check backend health
echo ""
print_info "Backend Health:"
if curl -s http://localhost:8000/health | jq '.status' | grep -q "ok"; then
    print_success "Backend API is healthy"
else
    print_error "Backend API health check failed"
fi

# Check simulation
echo ""
print_info "Simulation Status:"
if curl -s http://localhost:8000/simulation/status | jq '.running' | grep -q "true"; then
    print_success "Device simulation is running"
else
    print_warning "Device simulation is not running"
fi

# Check analytics
echo ""
print_info "Analytics Status:"
if curl -s http://localhost:8000/analytics/dashboard | jq '.available' | grep -q "true"; then
    print_success "Analytics dashboard is available"
else
    print_warning "Analytics dashboard is not available (this is OK if using S3)"
fi

# Check telemetry
echo ""
print_info "Telemetry Status:"
TELEMETRY_COUNT=$(curl -s http://localhost:8000/telemetry/metrics | jq '. | length')
if [ "$TELEMETRY_COUNT" -gt 0 ]; then
    print_success "Telemetry data available ($TELEMETRY_COUNT records)"
else
    print_warning "No telemetry data yet (may need a few moments)"
fi

# Final summary
print_header "🎉 Deployment Complete!"

echo ""
echo "=================================="
echo "Application URLs:"
echo "=================================="
echo ""
echo "  Frontend:    http://localhost:5173"
echo "  API Docs:    http://localhost:8000/docs"
echo "  Analytics:   http://localhost:5173/analytics"
echo "  Telemetry:   http://localhost:5173/telemetry"
echo ""
echo "=================================="
echo "Quick Commands:"
echo "=================================="
echo ""
echo "  # Stop services"
echo "  docker compose down"
echo ""
echo "  # View backend logs"
echo "  docker compose logs -f backend"
echo ""
echo "  # Stop simulation"
echo "  curl -X POST http://localhost:8000/simulation/stop"
echo ""
echo "  # Restart services"
echo "  docker compose restart backend frontend"
echo ""
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo ""
echo "  1. Open http://localhost:5173 in your browser"
echo "  2. Explore the analytics dashboard"
echo "  3. View real-time telemetry"
echo "  4. (Optional) Set up Tableflow for S3 analytics"
echo "     See: IaC/README.md (section Tableflow and S3)"
echo ""

print_success "Healthcare Shift-Left Demo is ready!"
print_info "For detailed documentation, see DEPLOYMENT_GUIDE.md"
