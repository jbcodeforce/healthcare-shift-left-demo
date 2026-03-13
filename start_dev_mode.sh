#!/bin/bash
# Development mode startup
# Uses the biz-db workspace configuration and data

set -e

# Get absolute paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"


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
    
    if [ $missing -eq 1 ]; then
        exit 1
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
    echo -e "  Config: $POSTGRES_CONFIG_FILE"
    
    docker compose up postgres -d
}

# Main execution
check_requirements
start_postgres
start_backend
start_frontend
LAN_IP=""
if command -v ipconfig &> /dev/null; then
  LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
elif command -v hostname &> /dev/null; then
  LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Development environment is running!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e ""
if [ -n "$LAN_IP" ]; then
  echo -e "  ${YELLOW}On your WiFi (other devices):${NC}"
  echo -e "    App:        http://${LAN_IP}:5173"
  echo -e "    Backend:    http://${LAN_IP}:8000"
fi

echo -e "  ${YELLOW}Frontend:${NC}       http://localhost:5173"
echo -e "  ${YELLOW}Backend:${NC}        http://localhost:8000"
echo -e "  ${YELLOW}API Docs:${NC}       http://localhost:8000/docs"
echo -e ""
echo -e "  Press ${RED}Ctrl+C${NC} to stop all services"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Wait for processes
wait

