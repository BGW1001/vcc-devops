#!/usr/bin/env bash
# VCC Platform Bootstrap Script
# Sets up full local development environment
# Onboarding target: < 15 minutes on clean Ubuntu 22.04
set -e

echo "🐴 VCC Platform Bootstrap"
echo "=========================="

# --- CHECK PREREQUISITES ---
echo ""
echo "Checking prerequisites..."

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  ✅ $1: $(command -v $1)"
        return 0
    else
        echo "  ❌ $1: NOT FOUND"
        return 1
    fi
}

FAILED=0
check_cmd docker || FAILED=1
check_cmd git    || FAILED=1
check_cmd python3 || FAILED=1
check_cmd pip    || FAILED=1

PYTHON_VER=$(python3 --version 2>&1 | grep -oP '3\.\d+')
if [[ "$PYTHON_VER" < "3.11" ]]; then
    echo "  ❌ Python $PYTHON_VER found — need 3.11+"
    FAILED=1
else
    echo "  ✅ Python $PYTHON_VER"
fi

if [[ $FAILED -eq 1 ]]; then
    echo ""
    echo "❌ Missing prerequisites. Install them and re-run."
    exit 1
fi

# --- CLONE REPOS ---
echo ""
echo "Cloning VCC repos..."

WORKSPACE=${VCC_WORKSPACE:-$HOME/vcc-workspace}
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

repos=(
    "vcc-config"
    "vcc-market-data"
    "vcc-financial-models"
    "vcc-nocode-quantlib"
    "vcc-devops"
    "vcc-platform"
)

for repo in "${repos[@]}"; do
    if [[ -d "$repo" ]]; then
        echo "  ✅ $repo: already cloned, pulling latest..."
        git -C "$repo" pull --ff-only 2>/dev/null || echo "  ⚠️  $repo: pull skipped (local changes)"
    else
        echo "  📦 Cloning $repo..."
        git clone "https://github.com/BGW1001/$repo.git" "$repo"
        echo "  ✅ $repo: $(git -C $repo log --oneline -1)"
    fi
done

# --- INSTALL WHEELS ---
echo ""
echo "Installing VCC wheels..."

pip install \
    "vcc-config==1.0.0" \
    "vcc-financial-models==0.1.0" \
    "vcc-market-data==0.1.0" \
    --quiet
echo "  ✅ All wheels installed"

# --- START CORE SERVICES ---
echo ""
echo "Starting core services..."

cd "$WORKSPACE/vcc-platform"
if [[ -f "docker-compose.yml" ]]; then
    docker-compose --profile core up -d 2>/dev/null && echo "  ✅ Core services started (Redis)" || echo "  ⚠️  docker-compose up failed (non-fatal)"
else
    echo "  ⚠️  docker-compose.yml not found, skipping services"
fi

# --- VERIFY ---
echo ""
echo "Verifying installation..."

python3 -c "from vcc_config.schemas import Deal; print('  ✅ vcc-config importable')"
python3 -c "from vcc_financial_models.bond_analytics import yield_to_price; print('  ✅ vcc-financial-models importable')"
python3 -c "from vcc_market_data.providers.yfinance_provider import YFinanceProvider; print('  ✅ vcc-market-data importable')"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  cd $WORKSPACE/vcc-platform"
echo "  docker-compose --profile quants up -d   # Start QuantLib server + Redis + Postgres"
echo "  curl http://localhost:8098/health        # Verify QuantLib server"
echo ""
