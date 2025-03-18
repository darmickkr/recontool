#!/bin/bash
# Script 1: Subdomain Enumeration using Amass & Subfinder

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

mkdir -p recon/$TARGET

# Using Amass for subdomain enumeration
amass enum -passive -d $TARGET -o recon/$TARGET/amass_subs.txt

# Using Subfinder for additional subdomains
subfinder -d $TARGET -o recon/$TARGET/subfinder_subs.txt

# Merging and sorting unique subdomains
cat recon/$TARGET/*_subs.txt | sort -u > recon/$TARGET/final_subdomains.txt

echo "Subdomain enumeration completed. Results saved in recon/$TARGET/final_subdomains.txt"

########################################

#!/bin/bash
# Script 2: Port Scanning using Nmap

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain/IP>"
    exit 1
fi

mkdir -p recon/$TARGET

# Running Nmap for open ports
echo "Scanning for open ports on $TARGET..."
nmap -p- -T4 -oN recon/$TARGET/ports.txt $TARGET

echo "Port scanning completed. Results saved in recon/$TARGET/ports.txt"

########################################

#!/bin/bash
# Script 3: Technology Fingerprinting using WhatWeb

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

mkdir -p recon/$TARGET

# Running WhatWeb to detect technologies
echo "Fingerprinting technologies used by $TARGET..."
whatweb -v $TARGET > recon/$TARGET/technology.txt

echo "Technology fingerprinting completed. Results saved in recon/$TARGET/technology.txt"

########################################

#!/bin/bash
# Script 4: Whois and DNS Lookup

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

mkdir -p recon/$TARGET

# Running whois lookup
whois $TARGET > recon/$TARGET/whois.txt

echo "Whois lookup completed. Results saved in recon/$TARGET/whois.txt"

# Running Dig for DNS records
dig $TARGET ANY +noall +answer > recon/$TARGET/dns_records.txt

echo "DNS lookup completed. Results saved in recon/$TARGET/dns_records.txt"

########################################

#!/bin/bash
# Script 5: Web Screenshot Capture using Aquatone

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

mkdir -p recon/$TARGET

# Running Aquatone for web screenshots
echo "$TARGET" | aquatone -out recon/$TARGET/screenshots

echo "Web screenshot capture completed. Results saved in recon/$TARGET/screenshots"

########################################

#!/bin/bash
# Script 6: Automated Recon System (Combining All)

TARGET=$1

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

mkdir -p recon/$TARGET

# Running all recon scripts
echo "Starting automated recon on $TARGET..."

bash subdomain_enum.sh $TARGET
bash port_scan.sh $TARGET
bash tech_fingerprint.sh $TARGET
bash whois_dns.sh $TARGET
bash web_screenshot.sh $TARGET

echo "Automated recon completed. All results saved in recon/$TARGET/"
