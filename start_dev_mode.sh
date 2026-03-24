#!/bin/bash
# Development mode startup
# Uses the biz-db workspace configuration and data

set -e

# Get absolute paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
CONNECT_DIR="$PROJECT_ROOT/connect"
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
# Connector name (same as connect/register-connector.sh; override via backend/.env DEBEZIUM_CONNECTOR_NAME)
if [ -f "$BACKEND_DIR/.env" ]; then
  set -a; source "$BACKEND_DIR/.env" 2>/dev/null; set +a
fi
CONNECTOR_NAME="${DEBEZIUM_CONNECTOR_NAME:-debezium-postgres-healthcare}"
DATA_TOPIC="${DEBEZIUM_TOPIC_PREFIX:-healthcare}.public.prescriptions"
CC_ENV_NAME="${FLINK_ENV_NAME}"
CC_KAFKA_NAME="${FLINK_DATABASE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Development Mode${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo -e "  Project Root:  $PROJECT_ROOT"



# Function to cleanup on exit (only kills processes we started)
cleanup() {
    echo -e "\n${YELLOW}Shutting down services...${NC}"
    if [ -n "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null && echo -e "${GREEN}Backend stopped${NC}"
    fi
    if [ -n "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null && echo -e "${GREEN}Frontend stopped${NC}"
    fi
    echo -e "${YELLOW}Stopping Kafka Connect...${NC}"
    docker compose down
    exit 0
}

trap cleanup SIGINT SIGTERM

# Check for required tools
check_requirements() {
    local missing=0
    
    if ! command -v uv &> /dev/null; then
        echo -e "${RED}Error: 'uv' is not installed${NC}"
        echo "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
        missing=1
    fi
    
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Error: 'node' is not installed${NC}"
        missing=1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}Error: 'npm' is not installed${NC}"
        missing=1
    fi
    
    if ! command -v confluent &> /dev/null; then
        echo -e "${RED}Error: 'confluent' is not installed${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi

}

# Verify Confluent Cloud authentication (required for verify_topics / Kafka CLI usage).
# Tries current CLI shapes: `confluent cloud environment list` then `confluent environment list`.
check_confluent_cloud_login() {
    local auth_ok=1
    if confluent cloud environment list &>/dev/null; then
        auth_ok=0
    elif confluent environment list &>/dev/null; then
        auth_ok=0
    fi
    if [ "$auth_ok" -ne 0 ]; then
        echo -e "${RED}Error: Confluent CLI is not logged in or authentication failed.${NC}"
        echo "  Log in to Confluent Cloud:"
        echo "    confluent login"
        echo "It will impact topic creation for CDC connector, if topic already exists, ignore this login constraint"
    else
        echo -e "${GREEN}Confluent CLI: authenticated to Confluent Cloud.${NC}"
    fi
}

# Start backend
start_backend() {
    echo -e "\n${GREEN}Starting Backend...${NC}"
    echo -e "  Port: 8000"
    echo -e "  Config: $CONFIG_FILE"
    
    cd "$BACKEND_DIR"
    export DATABASE_URL=postgresql://${POSTGRES_USER:-demo}:${POSTGRES_PASSWORD:-demo}@localhost:5432/${POSTGRES_DB:-healthcare}
    
    # Run uvicorn from workspace directory so relative paths in config.yaml work
    uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000 &
    
    BACKEND_PID=$!
    echo -e "  PID: $BACKEND_PID"
    
    # Wait for backend to be ready
    echo -e "  ${YELLOW}Waiting for backend to start...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            echo -e "  ${GREEN}Backend is ready!${NC}"
            break
        fi
        sleep 1
    done
}

# Start frontend
start_frontend() {
    echo -e "\n${GREEN}Starting Frontend...${NC}"
    echo -e "  Port: 5173"
    
    cd "$FRONTEND_DIR"
    
    # Install dependencies if node_modules is missing
    if [ ! -d "node_modules" ]; then
        echo -e "  ${YELLOW}Installing dependencies...${NC}"
        npm install
    fi
    
    npm run dev &
    FRONTEND_PID=$!
    echo -e "  PID: $FRONTEND_PID"
    
    # Wait for frontend to be ready
    echo -e "  ${YELLOW}Waiting for frontend to start...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:5173 > /dev/null 2>&1; then
            echo -e "  ${GREEN}Frontend is ready!${NC}"
            break
        fi
        sleep 1
    done
}

start_postgres() {
    echo -e "\n${GREEN}Starting PostgreSQL...${NC}"
    echo -e "  Port: 5432"
    cd "$PROJECT_ROOT"
    docker compose up postgres -d
}

# Check if Kafka Connect is running (REST API responds)
connect_is_running() {
    curl -sf "${CONNECT_URL}/connectors" > /dev/null 2>&1
}

# Check if the Debezium connector is defined
connector_is_defined() {
    curl -sf "${CONNECT_URL}/connectors/${CONNECTOR_NAME}" > /dev/null 2>&1
}

verify_topics() {
    echo -e "\n${GREEN}Verifying topics...${NC}"
    if ! confluent kafka topic list --environment ${ENV_ID} --cluster ${KAFKA_CLUSTER_ID}  | grep -q "${DATA_TOPIC}"; then
        echo -e "  ${YELLOW}Topic ${DATA_TOPIC} not found. Creating...${NC}"
        ${CONNECT_DIR}/create-topics.sh
    else
        echo -e "  ${GREEN}Topic ${DATA_TOPIC} found.${NC}"
    fi
}

# Ensure Kafka Connect is running and the Debezium connector is registered.
# Requires backend/.env with Kafka/Schema Registry vars. Skips if .env missing or Connect fails to start.
ensure_kafka_connect() {
    if [ ! -f "$BACKEND_DIR/.env" ]; then
        echo -e "\n${YELLOW}Kafka Connect: skipped (no backend/.env)${NC}"
        return 0
    fi

    echo -e "\n${GREEN}Kafka Connect${NC}"
    echo -e "  URL: $CONNECT_URL"

    if connect_is_running; then
        echo -e "  ${GREEN}Connect is already running.${NC}"
    else
        echo -e "  ${YELLOW}Connect not running, starting with Docker Compose...${NC}"
        cd "$PROJECT_ROOT"
        if ! docker compose --env-file "$BACKEND_DIR/.env" up kafka-connect -d 2>/dev/null; then
            echo -e "  ${YELLOW}Could not start Kafka Connect (check Kafka credentials in backend/.env). Continuing without Connect.${NC}"
            return 0
        fi
        echo -e "  ${YELLOW}Waiting for Connect to be ready...${NC}"
        local i=0
        while [ $i -lt 60 ]; do
            if connect_is_running; then
                echo -e "  ${GREEN}Connect is ready.${NC}"
                break
            fi
            sleep 5
            i=$((i + 5))
        done
        if ! connect_is_running; then
            echo -e "  ${YELLOW}Connect did not become ready in time. Register the connector later: ./connect/register-connector.sh${NC}"
            return 0
        fi
    fi

    if connector_is_defined; then
        echo -e "  ${GREEN}Connector ${CONNECTOR_NAME} is already defined.${NC}"
    else
        echo -e "  ${YELLOW}Connector not defined. Registering...${NC}"
        export CONNECT_URL
        if "$CONNECT_DIR/register-connector.sh"; then
            echo -e "  ${GREEN}Connector ${CONNECTOR_NAME} registered.${NC}"
        else
            echo -e "  ${YELLOW}Failed to register connector. Run manually: ./connect/register-connector.sh${NC}"
        fi
    fi
}

# Main execution
check_requirements
cd "$PROJECT_ROOT"
start_postgres
start_backend
start_frontend
check_confluent_cloud_login
verify_topics
ensure_kafka_connect


echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Development environment is running!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e ""
echo -e "  ${YELLOW}Frontend:${NC}       http://localhost:5173"
echo -e "  ${YELLOW}Confluent Cloud Environment:${NC}       ${CC_ENV_NAME}"
echo -e "  ${YELLOW}Confluent Cloud Kafka:${NC}       ${CC_KAFKA_NAME}"
echo -e "  ${YELLOW}Backend API Docs:${NC}       http://localhost:8000/docs"
echo -e "  ${YELLOW}Kafka Connect:${NC}  ${CONNECT_URL} (if started)"
echo -e ""
echo -e "  Press ${RED}Ctrl+C${NC} to stop all services"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Wait for processes
wait

