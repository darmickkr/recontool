#!/bin/bash

# Simple Port Scanner Script
# Usage: ./port_scanner.sh <target_host>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target_host>"
    exit 1
fi

target_host=$1
outfile="port_scan_results.txt"

# Check if nmap is installed
if ! command -v nmap &> /dev/null; then
    echo "nmap is not installed. Please install it first."
    exit 1
fi

echo "Starting port scan on $target_host..."
nmap -p- -sV -T4 -oN "$outfile" "$target_host"

echo "Port scanning completed. Results saved in $outfile."
