#!/bin/bash
# Build wrapper that captures all output to log files

echo "Starting KernelSU build with logging..."
echo "========================================"

# Create logs directory
mkdir -p logs

# Run apollo.sh with full output capture
{
    echo "Build started at: $(date)"
    echo "Command: ./apollo.sh"
    echo "Input: 1, 4, 1, Y, Y"
    echo ""
    
    # Run the build with all inputs
    echo -e "1\n4\n1\nY\nY" | ./apollo.sh 2>&1
    
    echo ""
    echo "Build completed at: $(date)"
    echo "Exit code: $?"
} > logs/build_$(date +%Y%m%d_%H%M%S).log 2>&1

echo "Build log saved to logs/"
echo "Check the latest log file for details"
