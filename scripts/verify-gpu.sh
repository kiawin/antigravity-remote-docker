#!/bin/bash

# GPU Verification Script (runs inside container)
# Verifies that the GPU is accessible from within the container

set -e

GPU_TYPE="${GPU_TYPE:-cpu}"

echo "========================================="
echo "GPU Verification (Type: $GPU_TYPE)"
echo "========================================="

case "$GPU_TYPE" in
    nvidia)
        echo "Checking NVIDIA GPU..."
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi
            if [ $? -eq 0 ]; then
                echo "✓ NVIDIA GPU is accessible"
                exit 0
            else
                echo "✗ NVIDIA GPU is NOT accessible"
                exit 1
            fi
        else
            echo "✗ nvidia-smi not found"
            exit 1
        fi
        ;;
    
    amd)
        echo "Checking AMD GPU..."
        
        # Check for ROCm devices
        if [ ! -c "/dev/kfd" ]; then
            echo "✗ /dev/kfd not found"
            exit 1
        fi
        
        if [ ! -d "/dev/dri" ]; then
            echo "✗ /dev/dri not found"
            exit 1
        fi
        
        echo "✓ ROCm devices found"
        
        # Check rocm-smi if available
        if command -v rocm-smi &> /dev/null; then
            rocm-smi
            if [ $? -eq 0 ]; then
                echo "✓ AMD GPU is accessible"
            fi
        fi
        
        # Check rocminfo if available
        if command -v rocminfo &> /dev/null; then
            echo "Running rocminfo..."
            rocminfo | head -n 20
        fi
        
        exit 0
        ;;
    
    intel)
        echo "Checking Intel GPU..."
        
        # Check for DRI devices
        if [ ! -d "/dev/dri" ]; then
            echo "✗ /dev/dri not found"
            exit 1
        fi
        
        echo "✓ DRI devices found:"
        ls -l /dev/dri/
        
        # Check vainfo if available
        if command -v vainfo &> /dev/null; then
            echo "Running vainfo..."
            LIBVA_DRIVER_NAME=iHD vainfo 2>&1 | head -n 20
            if [ $? -eq 0 ]; then
                echo "✓ Intel GPU is accessible"
            fi
        fi
        
        exit 0
        ;;
    
    cpu)
        echo "ℹ Running in CPU-only mode (no GPU)"
        exit 0
        ;;
    
    *)
        echo "✗ Unknown GPU type: $GPU_TYPE"
        exit 1
        ;;
esac
