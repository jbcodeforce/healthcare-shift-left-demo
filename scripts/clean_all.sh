#!/bin/bash
# Destructive full cleanup for healthcare-shift-left-demo:
# - Stops backend (8000) and frontend (5173) if listening on those ports
# - docker compose down (removes volumes by default = wipes Postgres data)
# - Removes backend/.venv and repo-root .venv
# - If shift_left is on PATH: sources set_j9r_env_sl when present, then
#   runs pipeline undeploy for each table (inventory + deploy short names)
#
# Usage:
#   ./clean_all.sh              # full clean including Docker volumes
#   ./clean_all.sh --keep-volumes   # docker compose down without -v

set +e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}/..")" && pwd)"
cd "$PROJECT_ROOT"

KEEP_VOLUMES=0
for arg in "$@"; do
  case "$arg" in
    --keep-volumes) KEEP_VOLUMES=1 ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Full cleanup (destructive)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

kill_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti ":$port" 2>/dev/null) || true
  if [ -n "$pids" ]; then
    echo -e "${YELLOW}Stopping process(es) on port ${port}: ${pids}${NC}"
    echo "$pids" | xargs kill -9 2>/dev/null || true
    echo -e "${GREEN}Port ${port} cleared.${NC}"
  else
    echo -e "  (nothing on port ${port})"
  fi
}

echo -e "\n${YELLOW}1) Stopping dev processes (ports 8000, 5173)...${NC}"
kill_port 8000
kill_port 5173

echo -e "\n${YELLOW}2) Docker Compose down...${NC}"
if ! command -v docker &>/dev/null; then
  echo -e "${RED}docker not found; skipping.${NC}"
else
  COMPOSE_DOWN=(docker compose)
  if [ -f "$PROJECT_ROOT/backend/.env" ]; then
    COMPOSE_DOWN+=(--env-file "$PROJECT_ROOT/backend/.env")
  fi
  COMPOSE_DOWN+=(down)
  if [ "$KEEP_VOLUMES" -eq 0 ]; then
    COMPOSE_DOWN+=(-v)
    echo -e "  ${RED}Removing named volumes (Postgres data will be wiped).${NC}"
  else
    echo -e "  ${YELLOW}Keeping volumes (--keep-volumes).${NC}"
  fi
  if ! "${COMPOSE_DOWN[@]}"; then
    if [ "$KEEP_VOLUMES" -eq 0 ]; then
      docker compose down -v 2>/dev/null || true
    else
      docker compose down 2>/dev/null || true
    fi
  fi
  echo -e "${GREEN}Docker compose stack stopped.${NC}"
fi


echo -e "\n${YELLOW}3) Pipeline undeploy (shift_left)...${NC}"
if ! command -v shift_left &>/dev/null; then
  echo -e "  ${YELLOW}shift_left not in PATH; skipping pipeline undeploy.${NC}"
else
  if [ -f "$PROJECT_ROOT/set_j9r_env_sl" ]; then
    # shellcheck source=/dev/null
    set -a
    source "$PROJECT_ROOT/set_j9r_env_sl" 2>/dev/null || true
    set +a
    echo -e "  Sourced set_j9r_env_sl"
  fi
  if [ -z "${FLINK_COMPUTE_POOL_ID:-}" ] && [ -z "${CCLOUD_COMPUTE_POOL_ID:-}" ]; then
    echo -e "${YELLOW}  FLINK_COMPUTE_POOL_ID / CCLOUD_COMPUTE_POOL_ID not set; undeploy may fail.${NC}"
  fi
  POOL_ARG=()
  if [ -n "${FLINK_COMPUTE_POOL_ID:-}" ]; then
    POOL_ARG=(--compute-pool-id "$FLINK_COMPUTE_POOL_ID")
  elif [ -n "${CCLOUD_COMPUTE_POOL_ID:-}" ]; then
    POOL_ARG=(--compute-pool-id "$CCLOUD_COMPUTE_POOL_ID")
  fi


  echo -e "  ${BLUE}shift_left pipeline undeploy ${NC}"
  shift_left pipeline undeploy  ${POOL_ARG[@]} --product-name rmd
  shift_left pipeline undeploy  ${POOL_ARG[@]} --product-name raw


fi

echo -e "\n${GREEN}Cleanup finished.${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
