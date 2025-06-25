#!/bin/bash
# scripts/install_docs_tools_fixed.sh
# Встановлення інструментів документації з virtual environment

echo " Installing documentation tools with virtual environment..."

# Check if python3-venv is installed
if ! python3 -c "import venv" &> /dev/null; then
    echo " Installing python3-venv..."
    sudo apt update
    sudo apt install -y python3-venv python3-full
fi

# Create virtual environment in docs directory
echo " Creating virtual environment..."
cd docs || {
    echo " Error: docs directory not found!"
    exit 1
}

python3 -m venv venv

# Activate virtual environment
echo " Activating virtual environment..."
source venv/bin/activate

# Upgrade pip in virtual environment
echo " Upgrading pip..."
pip install --upgrade pip

# Install Python packages
echo " Installing Python packages..."
pip install sphinx sphinx-rtd-theme

# Optional: install gdscript-parser if available
pip install gdscript-parser || echo " gdscript-parser not available, continuing without it"

# Create activation script for future use
cat > activate_docs.sh << 'EOF'
#!/bin/bash
# Activate documentation environment
echo " Activating documentation environment..."
cd docs
source venv/bin/activate
echo " Documentation environment active!"
echo " Run: sphinx-build -b html source build"
EOF

chmod +x activate_docs.sh

# Create structure
echo " Creating documentation structure..."
mkdir -p {source,build}
mkdir -p source/{api,architecture,development,quality}
mkdir -p source/{_static,_templates}

# Create requirements.txt
echo " Creating requirements.txt..."
cat > requirements.txt << 'EOF'
sphinx>=4.0.0
sphinx-rtd-theme>=1.0.0
EOF

# Create .gitignore
echo " Creating docs .gitignore..."
cat > .gitignore << 'EOF'
build/
_build/
.doctrees/
venv/
*.pyc
__pycache__/
EOF

echo "Documentation tools installed successfully!"
echo ""
echo "Next steps:"
echo "1. cd docs && source venv/bin/activate"
echo "2. sphinx-build -b html source build"
echo "3. open build/index.html"
echo ""
echo " Or use: cd docs && ./activate_docs.sh"