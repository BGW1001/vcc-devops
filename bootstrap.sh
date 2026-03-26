#!/usr/bin/env bash
# bootstrap.sh — VCC Platform environment prerequisites check
# Usage: ./bootstrap.sh
# Exit 0 if all prerequisites are met, 1 if any are missing.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; MISSING=$((MISSING+1)); }
info() { echo -e "${YELLOW}  →${NC} $1"; }

MISSING=0

echo ""
echo "======================================"
echo " VCC Platform — Bootstrap Prerequisites"
echo "======================================"
echo ""

# ── Docker ─────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
  DOCKER_VERSION=$(docker --version 2>&1)
  ok "Docker: $DOCKER_VERSION"
else
  fail "Docker not found. Install from https://docs.docker.com/get-docker/"
fi

# ── Git ─────────────────────────────────────────────────────────────────────
if command -v git &>/dev/null; then
  GIT_VERSION=$(git --version 2>&1)
  ok "Git: $GIT_VERSION"
else
  fail "Git not found. Install from https://git-scm.com/"
fi

# ── Python 3.11+ ────────────────────────────────────────────────────────────
PYTHON_CMD=""
for cmd in python3.13 python3.12 python3.11 python3 python; do
  if command -v "$cmd" &>/dev/null; then
    PYVER=$($cmd --version 2>&1 | awk '{print $2}')
    PYMAJOR=$(echo "$PYVER" | cut -d. -f1)
    PYMINOR=$(echo "$PYVER" | cut -d. -f2)
    if [[ "$PYMAJOR" -eq 3 && "$PYMINOR" -ge 11 ]]; then
      PYTHON_CMD=$cmd
      ok "Python: $PYVER (via $cmd)"
      break
    fi
  fi
done
if [[ -z "$PYTHON_CMD" ]]; then
  fail "Python 3.11+ not found. Install from https://python.org"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
if [[ "$MISSING" -eq 0 ]]; then
  echo -e "${GREEN}All prerequisites satisfied. VCC Platform is ready to run.${NC}"
  exit 0
else
  echo -e "${RED}$MISSING prerequisite(s) missing. Please install them and re-run bootstrap.sh.${NC}"
  exit 1
fi
