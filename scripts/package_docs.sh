#!/bin/bash
# Package generated documentation into archive

echo "Packaging documentation..."

# Ensure docs directory exists
cd docs || exit 1

# Create the build directory if it doesn't exist
mkdir -p build

# Copy your HTML documentation to build directory
cp -r ../documentation/* build/ 2>/dev/null || true
cp index.html build/ 2>/dev/null || true

# Create the archive that the instructor wants
zip -r generated_docs.zip build/
mv generated_docs.zip ../

echo "Documentation packaged as generated_docs.zip"
echo "Archive size: $(du -h ../generated_docs.zip | cut -f1)"
