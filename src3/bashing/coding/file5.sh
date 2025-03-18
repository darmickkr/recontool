#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target_domain>"
    exit 1
fi

TARGET=$1
SUBDOMAINS_FILE="subdomains.txt"
PORTS_FILE="ports.txt"
DIR_ENUM_RESULTS="dir_enum_results.txt"
SCREENSHOT_DIR="screenshots"

# Checking for dependencies
for cmd in amass nmap ffuf gowitness; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is not installed. Please install it first."
        exit 1
    fi
done

# Subdomain Enumeration
echo "[+] Enumerating subdomains for $TARGET..."
amass enum -passive -d $TARGET -o $SUBDOMAINS_FILE
echo "[+] Subdomain enumeration completed. Results saved in $SUBDOMAINS_FILE."

# Port Scanning
echo "[+] Scanning open ports..."
nmap -p- -T4 -sV -oN $PORTS_FILE $TARGET
echo "[+] Port scanning completed. Results saved in $PORTS_FILE."

# Directory Bruteforcing on discovered subdomains
if [ -s "$SUBDOMAINS_FILE" ]; then
    echo "[+] Performing directory brute-force on subdomains..."
    while read -r SUBDOMAIN; do
        ffuf -u "http://$SUBDOMAIN/FUZZ" -w /usr/share/wordlists/dirb/common.txt -o "$DIR_ENUM_RESULTS" -of json -c
    done < "$SUBDOMAINS_FILE"
    echo "[+] Directory brute-force completed. Results saved in $DIR_ENUM_RESULTS."
fi

# Taking Screenshots
echo "[+] Capturing screenshots of live subdomains..."
gowitness file -f "$SUBDOMAINS_FILE" -o "$SCREENSHOT_DIR"
echo "[+] Screenshots saved in $SCREENSHOT_DIR."

echo "[+] Reconnaissance completed successfully!"
