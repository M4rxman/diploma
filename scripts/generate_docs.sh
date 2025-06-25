#!/bin/bash
# scripts/generate_docs_fixed.sh
# Виправлений скрипт генерації документації

echo " Building project documentation..."

# Go to docs directory
cd docs || {
    echo " Error: docs directory not found!"
    exit 1
}

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo " Virtual environment not found!"
    echo " Run: ./scripts/install_docs_tools_fixed.sh first"
    exit 1
fi

# Activate virtual environment
echo " Activating virtual environment..."
source venv/bin/activate

# Check if Sphinx is installed
if ! command -v sphinx-build &> /dev/null; then
    echo " Sphinx not found in virtual environment!"
    echo " Installing Sphinx..."
    pip install sphinx sphinx-rtd-theme
fi

# Create custom CSS if it doesn't exist
echo " Creating custom styling..."
mkdir -p source/_static
cat > source/_static/custom.css << 'EOF'
/* Custom CSS for game documentation */
.wy-nav-content {
    max-width: none;
}

.rst-content .section > h1 {
    color: #2980b9;
    border-bottom: 3px solid #3498db;
}

.rst-content .section > h2 {
    color: #27ae60;
    border-bottom: 2px solid #2ecc71;
}

.rst-content pre.literal-block, 
.rst-content div[class^='highlight'] {
    background-color: #f8f8f8;
    border: 1px solid #e1e4e5;
    border-radius: 4px;
}
EOF

# Clean previous builds
echo " Cleaning previous builds..."
rm -rf build/*

# Check if source files exist
if [ ! -f "source/conf.py" ]; then
    echo " conf.py not found!"
    echo " Create docs/source/conf.py file first"
    exit 1
fi

if [ ! -f "source/index.rst" ]; then
    echo " index.rst not found!"
    echo " Create docs/source/index.rst file first"
    exit 1
fi

# Build documentation
echo " Building HTML documentation..."
sphinx-build -b html source build

if [ $? -eq 0 ]; then
    echo ""
    echo " Documentation generated successfully!"
    echo " Location: $(pwd)/build/index.html"
    
    # Try to open documentation
    if command -v xdg-open &> /dev/null; then
        echo " Opening documentation..."
        xdg-open build/index.html
    else
        echo " Open: file://$(pwd)/build/index.html"
    fi
else
    echo ""
    echo " Documentation build failed!"
    echo " Check the error messages above"
fi

# Return to project root
cd ..