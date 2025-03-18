#!/bin/bash

# Subdomain Enumeration Script
# Usage: ./subdomain_enum.sh <target_domain>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target_domain>"
    exit 1
fi

target_domain=$1
wordlist="/usr/share/wordlists/subdomains.txt"
outfile="subdomain_enum_results.txt"

# Check if required tools are installed
if ! command -v subfinder &> /dev/null; then
    echo "subfinder is not installed. Please install it first."
    exit 1
fi
if ! command -v assetfinder &> /dev/null; then
    echo "assetfinder is not installed. Please install it first."
    exit 1
fi
if ! command -v amass &> /dev/null; then
    echo "amass is not installed. Please install it first."
    exit 1
fi

# Start Subdomain Enumeration
echo "Starting subdomain enumeration for $target_domain..."
subfinder -d "$target_domain" > subfinder_results.txt
assetfinder --subs-only "$target_domain" > assetfinder_results.txt
amass enum -passive -d "$target_domain" > amass_results.txt

# Merge results and remove duplicates
cat subfinder_results.txt assetfinder_results.txt amass_results.txt | sort -u > "$outfile"

# Display results
echo "Subdomain enumeration completed. Results saved in $outfile."
cat "$outfile"
