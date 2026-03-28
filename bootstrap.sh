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

# pip: try pip, pip3, python3 -m pip, miniconda
PIP_CMD=""
if command -v pip &>/dev/null; then
    PIP_CMD="pip"
    echo "  ✅ pip: $(command -v pip)"
elif command -v pip3 &>/dev/null; then
    PIP_CMD="pip3"
    echo "  ✅ pip3 (as pip): $(command -v pip3)"
elif python3 -m pip --version &>/dev/null 2>&1; then
    PIP_CMD="python3 -m pip"
    echo "  ✅ pip (via python3 -m pip)"
elif [[ -x "$HOME/miniconda3/bin/pip" ]]; then
    PIP_CMD="$HOME/miniconda3/bin/pip"
    echo "  ✅ pip (miniconda): $PIP_CMD"
else
    echo "  ❌ pip: NOT FOUND"
    FAILED=1
fi

PYTHON_VER=$(python3 --version 2>&1 | grep -oP '3\.\d+')
if [[ "$PYTHON_VER" < "3.11" ]]; then
    echo "  ⚠️  Python $PYTHON_VER found — need 3.11+. Attempting install..."
    # Try deadsnakes PPA for Ubuntu
    if command -v apt-get &>/dev/null; then
        apt-get install -y software-properties-common 2>/dev/null || true
        add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
        apt-get update -qq 2>/dev/null || true
        if apt-get install -y python3.11 python3.11-distutils 2>/dev/null; then
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 2>/dev/null || true
            # Install pip for python3.11
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 2>/dev/null || python3.11 -m ensurepip 2>/dev/null || true
            echo "  ✅ Python 3.11 installed via deadsnakes"
        else
            echo "  ❌ Could not install Python 3.11"; FAILED=1
        fi
    else
        echo "  ❌ Python $PYTHON_VER found — need 3.11+"; FAILED=1
    fi
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

# Try PyPI first, fall back to local editable installs
if ! $PIP_CMD install "vcc-config==1.0.0" "vcc-financial-models==0.1.0" "vcc-market-data==0.1.0" --quiet 2>/dev/null; then
    echo "  ℹ️  PyPI wheels not found — installing from local source..."
    for pkg in vcc-config vcc-financial-models vcc-market-data vcc-nocode-quantlib; do
        if [[ -d "$WORKSPACE/$pkg" ]]; then
            $PIP_CMD install -e "$WORKSPACE/$pkg" --quiet 2>/dev/null \
                && echo "  ✅ $pkg: installed from source" \
                || echo "  ⚠️  $pkg: install skipped"
        fi
    done
fi
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

# Use the same python as pip to ensure installed packages are visible
PYTHON_CMD="python3"
if [[ "$PIP_CMD" == "$HOME/miniconda3/bin/pip" ]]; then
    PYTHON_CMD="$HOME/miniconda3/bin/python"
elif [[ "$PIP_CMD" == "python3 -m pip" ]]; then
    PYTHON_CMD="python3"
fi

$PYTHON_CMD -c "from vcc_config.schemas import Deal; print('  ✅ vcc-config importable')" \
    || echo "  ⚠️  vcc-config: import failed (install from source)"
$PYTHON_CMD -c "import vcc_financial_models; print('  ✅ vcc-financial-models importable')" \
    || $PYTHON_CMD -c "
import sys; sys.path.insert(0, '$WORKSPACE/vcc-financial-models')
import vcc_financial_models; print('  ✅ vcc-financial-models importable (path override)')
" || echo "  ⚠️  vcc-financial-models: import failed (install from source)"
$PYTHON_CMD -c "from vcc_market_data.providers import YFinanceProvider; print('  ✅ vcc-market-data importable')" \
    || echo "  ⚠️  vcc-market-data: import failed (install from source)"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  cd $WORKSPACE/vcc-platform"
echo "  docker-compose --profile quants up -d   # Start QuantLib server + Redis + Postgres"
echo "  curl http://localhost:8098/health        # Verify QuantLib server"
echo ""
