#!/bin/bash
# Activate documentation environment
echo " Activating documentation environment..."
cd docs
source venv/bin/activate
echo " Documentation environment active!"
echo " Run: sphinx-build -b html source build"
