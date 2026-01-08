#!/bin/bash

# GPU Auto-Detection Script
# This script detects the available GPU type on the host system

set -e

echo "========================================="
echo "GPU Auto-Detection"
echo "========================================="

GPU_TYPE="cpu"

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "✓ NVIDIA GPU detected"
        GPU_TYPE="nvidia"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    fi
fi

# Check for AMD GPU
if [ "$GPU_TYPE" = "cpu" ]; then
    if [ -d "/sys/module/amdgpu" ] && ([ -c "/dev/kfd" ] || [ -d "/dev/dri" ]); then
        echo "✓ AMD GPU detected"
        GPU_TYPE="amd"
        if command -v rocm-smi &> /dev/null; then
            rocm-smi --showproductname 2>/dev/null || echo "  (rocm-smi not available for details)"
        fi
    fi
fi

# Check for Intel GPU
if [ "$GPU_TYPE" = "cpu" ]; then
    if [ -d "/dev/dri" ]; then
        if lspci 2>/dev/null | grep -i "VGA.*Intel" &> /dev/null; then
            echo "✓ Intel GPU detected"
            GPU_TYPE="intel"
            lspci | grep -i "VGA.*Intel"
        fi
    fi
fi

# No GPU found
if [ "$GPU_TYPE" = "cpu" ]; then
    echo "ℹ No GPU detected, will use CPU-only mode"
fi

echo "========================================="
echo "Detected GPU Type: $GPU_TYPE"
echo "========================================="

# Copy the appropriate .env file
if [ -f ".env.${GPU_TYPE}" ]; then
    echo "Copying .env.${GPU_TYPE} to .env"
    cp ".env.${GPU_TYPE}" .env
    echo "✓ Configuration file ready"
else
    echo "⚠ Warning: .env.${GPU_TYPE} not found"
    echo "  Using default configuration"
fi

echo ""
echo "To build and run the container:"
echo "  docker-compose up -d --build"
