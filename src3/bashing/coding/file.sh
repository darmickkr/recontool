#!/bin/bash

DOMAIN=""
OUTPUT_DIR="./output"
WORDLIST="wordlist.txt"
AMASS_OUTPUT="amass_output.txt"
SUBLIST3R_OUTPUT="sublist3r_output.txt"
BRUTE_FORCE_OUTPUT="brute_force_output.txt"
RESOLVED_OUTPUT="resolved_subdomains.txt"
LIVE_HTTP_OUTPUT="live_http_subdomains.txt"
LIVE_HTTPS_OUTPUT="live_https_subdomains.txt"
COMBINED_OUTPUT="combined_subdomains.txt"
UNIQUE_OUTPUT="unique_subdomains.txt"
WHOIS_OUTPUT="whois_output.txt"
HTTP_STATUS_LOG="http_status.log"
MASSDNS_RESOLVER="/path/to/resolvers.txt"
PARALLEL_JOBS=50
WHOIS_LIMIT=15
RETRY_LIMIT=5
DELAY=2
DNS_RECORDS=("A" "AAAA" "MX" "TXT" "CNAME" "NS" "PTR" "SRV" "SOA")
API_KEYS=("API_KEY1" "API_KEY2")
API_LIMIT=100
TIMEOUT=30
MAX_RETRIES=5
REMOTE_HOSTS=("remote_host_1" "remote_host_2")
THREAT_INTEL_APIS=("https://api.shodan.io" "https://www.censys.io")
RATE_LIMIT=200
SCHEDULE_TASK=false
INCLUDE_SCRAPING=true
CLI_LOG_FILE="script.log"
DB_NAME="subdomains.db"
DB_TABLE="subdomain_data"
USE_DATABASE=true
HTTP_STATUS_CODES=("200" "301" "302" "301" "404" "403")
FETCH_HTTP_HEADERS=false
MONITOR_SLEEP_INTERVAL=60
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/XXX/XXX"
NMAP_SCAN=false
NMAP_SCAN_OUTPUT="nmap_scan.txt"

while getopts "d:w:o:p:r:t:l:s" opt; do
    case $opt in
        d) DOMAIN=$OPTARG ;;
        w) WORDLIST=$OPTARG ;;
        o) OUTPUT_DIR=$OPTARG ;;
        p) PARALLEL_JOBS=$OPTARG ;;
        r) RETRY_LIMIT=$OPTARG ;;
        t) TIMEOUT=$OPTARG ;;
        l) WHOIS_LIMIT=$OPTARG ;;
        s) INCLUDE_SCRAPING=true ;;
        \?) echo "Usage: $0 [-d domain] [-w wordlist] [-o output_dir] [-p parallel_jobs] [-r retry_limit] [-t timeout] [-l whois_limit]" && exit 1 ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo "Domain (-d) is required."
    exit 1
fi

mkdir -p $OUTPUT_DIR

command_exists() {
    command -v "$1" &>/dev/null
}

for tool in dig amass sublist3r dnsrecon massdns curl parallel jq whois python3 ssh sqlite3 nmap; do
    if ! command_exists "$tool"; then
        echo "$tool is not installed. Exiting."
        exit 1
    fi
done

log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$OUTPUT_DIR/$CLI_LOG_FILE"
}

retry_command() {
    local command=$1
    local retries=$2
    local delay=$3
    local count=0
    until $command; do
        count=$((count+1))
        if [ $count -ge $retries ]; then
            echo "Command failed after $retries attempts. Exiting."
            return 1
        fi
        echo "Retrying in $delay seconds..."
        sleep $delay
    done
}

setup_database() {
    if [ "$USE_DATABASE" = true ]; then
        sqlite3 "$OUTPUT_DIR/$DB_NAME" "CREATE TABLE IF NOT EXISTS $DB_TABLE (subdomain TEXT, resolved_ip TEXT, http_status INTEGER, https_status INTEGER, whois_data TEXT);"
    fi
}

store_to_database() {
    if [ "$USE_DATABASE" = true ]; then
        sqlite3 "$OUTPUT_DIR/$DB_NAME" "INSERT INTO $DB_TABLE (subdomain, resolved_ip, http_status, https_status, whois_data) VALUES ('$1', '$2', $3, $4, '$5');"
    fi
}

send_slack_alert() {
    local message=$1
    if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$message"'"}' $SLACK_WEBHOOK_URL
    fi
}

dns_query() {
    log_message "Running DNS query for $DOMAIN..."
    dig +short NS $DOMAIN > "$OUTPUT_DIR/dns_query.txt"
}

sublist3r_enumeration() {
    log_message "Running Sublist3r for subdomain enumeration..."
    sublist3r -d $DOMAIN -o "$OUTPUT_DIR/$SUBLIST3R_OUTPUT"
}

amass_enumeration() {
    log_message "Running Amass for subdomain enumeration..."
    amass enum -d $DOMAIN -o "$OUTPUT_DIR/$AMASS_OUTPUT"
}

dnsrecon_enumeration() {
    log_message "Running DNSRecon for subdomain enumeration..."
    dnsrecon -d $DOMAIN -t std -o "$OUTPUT_DIR/dnsrecon_output.txt"
}

massdns_enumeration() {
    log_message "Running MassDNS for subdomain enumeration..."
    if [ ! -f "$MASSDNS_RESOLVER" ]; then
        echo "Resolver file $MASSDNS_RESOLVER not found. Exiting."
        exit 1
    fi
    massdns -r "$MASSDNS_RESOLVER" -t A -o S -w "$OUTPUT_DIR/massdns_output.txt" $DOMAIN
}

brute_force_enumeration() {
    log_message "Running brute force subdomain enumeration using wordlist $WORDLIST..."
    cat $WORDLIST | parallel -j $PARALLEL_JOBS "dig +short {}.$DOMAIN" > "$OUTPUT_DIR/$BRUTE_FORCE_OUTPUT"
}

whois_lookup() {
    log_message "Running WHOIS lookup for discovered subdomains..."
    cat "$OUTPUT_DIR/$UNIQUE_OUTPUT" | parallel -j $WHOIS_LIMIT "whois {}" > "$OUTPUT_DIR/$WHOIS_OUTPUT"
}

merge_results() {
    log_message "Merging results from all tools..."
    cat "$OUTPUT_DIR/$AMASS_OUTPUT" "$OUTPUT_DIR/$SUBLIST3R_OUTPUT" "$OUTPUT_DIR/dnsrecon_output.txt" "$OUTPUT_DIR/$BRUTE_FORCE_OUTPUT" "$OUTPUT_DIR/massdns_output.txt" | sort -u > "$OUTPUT_DIR/$COMBINED_OUTPUT"
    sort -u "$OUTPUT_DIR/$COMBINED_OUTPUT" -o "$OUTPUT_DIR/$UNIQUE_OUTPUT"
}

resolve_subdomains() {
    log_message "Resolving subdomains..."
    for record in "${DNS_RECORDS[@]}"; do
        cat "$OUTPUT_DIR/$UNIQUE_OUTPUT" | parallel -j $PARALLEL_JOBS "dig +short {} $record" > "$OUTPUT_DIR/${record}_resolved.txt"
    done
}

check_live_http_https() {
    log_message "Checking HTTP(S) response codes for subdomains..."
    while read -r subdomain; do
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$subdomain")
        https_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$subdomain")
        if [[ " ${HTTP_STATUS_CODES[@]} " =~ " $http_status " ]]; then
            echo "$subdomain,$http_status" >> "$OUTPUT_DIR/$LIVE_HTTP_OUTPUT"
        fi
        if [[ " ${HTTP_STATUS_CODES[@]} " =~ " $https_status " ]]; then
            echo "$subdomain,$https_status" >> "$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT"
        fi
    done < "$OUTPUT_DIR/$UNIQUE_OUTPUT"
}

generate_reports() {
    log_message "Generating CSV and HTML reports..."
    echo "Subdomain,Resolved IPs,HTTP Status,HTTPS Status" > "$OUTPUT_DIR/report.csv"
    while read -r subdomain; do
        http_status=$(grep -o "$subdomain" "$OUTPUT_DIR/$LIVE_HTTP_OUTPUT" | wc -l)
        https_status=$(grep -o "$subdomain" "$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT" | wc -l)
        echo "$subdomain,$http_status,$https_status" >> "$OUTPUT_DIR/report.csv"
    done < "$OUTPUT_DIR/$UNIQUE_OUTPUT"

    echo "<html><head><title>Subdomain Report</title></head><body><h1>Subdomain Enumeration Report</h1><table border='1'><tr><th>Subdomain</th><th>Resolved IPs</th><th>HTTP Status</th><th>HTTPS Status</th></tr>" > "$OUTPUT_DIR/report.html"
    while read -r subdomain; do
        http_status=$(grep -o "$subdomain" "$OUTPUT_DIR/$LIVE_HTTP_OUTPUT" | wc -l)
        https_status=$(grep -o "$subdomain" "$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT" | wc -l)
        echo "<tr><td>$subdomain</td><td>Resolved</td><td>$http_status</td><td>$https_status</td></tr>" >> "$OUTPUT_DIR/report.html"
    done < "$OUTPUT_DIR/$UNIQUE_OUTPUT"
    echo "</table></body></html>" >> "$OUTPUT_DIR/report.html"
}

schedule_task() {
    if [ "$SCHEDULE_TASK" = true ]; then
        log_message "Scheduling task for periodic checks..."
        crontab -l | { cat; echo "0 * * * * /path/to/this/script.sh -d $DOMAIN"; } | crontab -
    fi
}

If [ -z “$1” ]; then

    Echo “Usage: $0 <domain>”

    Exit 1

Fi

DOMAIN=$1

Mkdir -p $OUTPUT_DIR



Command_exists() {

    Command -v “$1” &>/dev/null

}

For tool in dig amass sublist3r dnsrecon massdns curl parallel jq whois python3; do

    If ! command_exists “$tool”; then

        Echo “$tool is not installed. Exiting.”

        Exit 1

    Fi

Done

Log_message() {

    Local message=$1

    Echo “$(date ‘+%Y-%m-%d %H:%M:%S’) - $message” >> “$OUTPUT_DIR/script_log.txt”

}

Dns_query() {

    Log_message “Running DNS query for $DOMAIN…”

    Dig +short NS $DOMAIN > “$OUTPUT_DIR/dns_query.txt”

}
Sublist3r_enumeration() {

    Log_message “Running Sublist3r for subdomain enumeration…”

    Sublist3r -d $DOMAIN -o “$OUTPUT_DIR/$SUBLIST3R_OUTPUT”

}

Amass_enumeration() {

    Log_message “Running Amass for subdomain enumeration…”

    Amass enum -d $DOMAIN -o “$OUTPUT_DIR/$AMASS_OUTPUT”

}

Dnsrecon_enumeration() {

    Log_message “Running DNSRecon for subdomain enumeration…”

    Dnsrecon -d $DOMAIN -t std -o “$OUTPUT_DIR/dnsrecon_output.txt”

}

Massdns_enumeration() {

    Log_message “Running MassDNS for subdomain enumeration…”

    If [ ! -f “$MASSDNS_RESOLVER” ]; then

        Echo “Resolver file $MASSDNS_RESOLVER not found. Exiting.”

        Exit 1

    Fi

    Massdns -r “$MASSDNS_RESOLVER” -t A -o S -w “$OUTPUT_DIR/massdns_output.txt” $DOMAIN

}
Brute_force_enumeration() {

    Log_message “Running brute force subdomain enumeration using wordlist $WORDLIST…”

    Cat $WORDLIST | parallel -j $PARALLEL_JOBS “dig +short {}.$DOMAIN” > “$OUTPUT_DIR/$BRUTE_FORCE_OUTPUT”

}

Whois_lookup() {

    Log_message “Running WHOIS lookup for discovered subdomains…”

    Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $WHOIS_LIMIT “whois {}” > “$OUTPUT_DIR/$WHOIS_OUTPUT”

}


Merge_results() {

    Log_message “Merging results from all tools…”

    Cat “$OUTPUT_DIR/$AMASS_OUTPUT” “$OUTPUT_DIR/$SUBLIST3R_OUTPUT” “$OUTPUT_DIR/dnsrecon_output.txt” “$OUTPUT_DIR/$BRUTE_FORCE_OUTPUT” “$OUTPUT_DIR/massdns_output.txt” | sort -u > “$OUTPUT_DIR/$COMBINED_OUTPUT”

    Sort -u “$OUTPUT_DIR/$COMBINED_OUTPUT” -o “$OUTPUT_DIR/$UNIQUE_OUTPUT”

}

Resolve_subdomains() {

    Log_message “Resolving subdomains…”

    For record in “${DNS_RECORDS[@]}”; do

        Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $PARALLEL_JOBS “dig +short {} $record” > “$OUTPUT_DIR/${record}_resolved.txt”

    Done

}

Check_live_http_https() {

    Log_message “Checking HTTP(S) response codes for subdomains…”

    While read -r subdomain; do

        http_status=$(curl -s -o /dev/null -w “%{http_code}” http://$subdomain)

        https_status=$(curl -s -o /dev/null -w “%{http_code}” https://$subdomain)

        if [ “$http_status” -eq 200 ]; then

            echo “$subdomain” >> “$OUTPUT_DIR/$LIVE_HTTP_OUTPUT”

        fi

        if [ “$https_status” -eq 200 ]; then

            echo “$subdomain” >> “$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT”

        fi

    done < “$OUTPUT_DIR/$UNIQUE_OUTPUT”

}

Optimized_dns_query() {

    Log_message “Performing optimized DNS queries using parallel…”

    Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $PARALLEL_JOBS “dig +short {}” > “$OUTPUT_DIR/$RESOLVED_OUTPUT”

}

Optimized_http_check() {

    Log_message “Optimized HTTP(S) check for live subdomains…”

    Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $PARALLEL_JOBS ‘curl -s -o /dev/null -I -w “%{http_code}” http://{} && echo “{}” >> ‘”$OUTPUT_DIR”/$LIVE_HTTP_OUTPUT

}

Check_whois() {

    Log_message “Performing WHOIS lookup for subdomains…”

    Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $WHOIS_LIMIT “whois {}” > “$OUTPUT_DIR/$WHOIS_OUTPUT”

}

Detect_shared_ip() {

    Log_message “Detecting shared IP addresses across subdomains…”

    Awk ‘{print $1}’ “$OUTPUT_DIR/$RESOLVED_OUTPUT” | sort | uniq -d > “$OUTPUT_DIR/shared_ips.txt”

    Echo “Shared IPs detected, saved to $OUTPUT_DIR/shared_ips.txt”

}

Whois_information() {

    Log_message “Retrieving WHOIS information for each subdomain…”

    Cat “$OUTPUT_DIR/$UNIQUE_OUTPUT” | parallel -j $WHOIS_LIMIT ‘whois {}’ >> “$OUTPUT_DIR/$WHOIS_OUTPUT”

}

Output_http_status() {

    Log_message “Outputting HTTP status codes…”

    Cat “$OUTPUT_DIR/$HTTP_STATUS_LOG”

}

Generate_reports() {

    Log_message “Generating CSV and HTML reports…”

    Echo “Subdomain,Resolved IPs,HTTP Status,HTTPS Status” > “$OUTPUT_DIR/report.csv”

    While read -r subdomain; do

        http_status=$(grep -o “$subdomain” “$OUTPUT_DIR/$LIVE_HTTP_OUTPUT” | wc -l)

        https_status=$(grep -o “$subdomain” “$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT” | wc -l)

        echo “$subdomain,$http_status,$https_status” >> “$OUTPUT_DIR/report.csv”

    done < “$OUTPUT_DIR/$UNIQUE_OUTPUT”
    echo “<html><head><title>Subdomain Report</title></head><body><h1>Subdomain Enumeration Report</h1><table border=’1’><tr><th>Subdomain</th><th>Resolved IPs</th><th>HTTP Status</th><th>HTTPS Status</th></tr>” > “$OUTPUT_DIR/report.html”

    while read -r subdomain; do

        http_status=$(grep -o “$subdomain” “$OUTPUT_DIR/$LIVE_HTTP_OUTPUT” | wc -l)

        https_status=$(grep -o “$subdomain” “$OUTPUT_DIR/$LIVE_HTTPS_OUTPUT” | wc -l)

        echo “<tr><td>$subdomain</td><td>$http_status</td><td>$https_status</td></tr>” >> “$OUTPUT_DIR/report.html”

    done < “$OUTPUT_DIR/$UNIQUE_OUTPUT”

    echo “</table></body></html>” >> “$OUTPUT_DIR/report.html”

}

Display_results() {

    Log_message “Subdomain enumeration completed.”

    Echo “Unique subdomains saved to: $OUTPUT_DIR/$UNIQUE_OUTPUT”

    Echo “Resolved subdomains saved to: $OUTPUT_DIR/$RESOLVED_OUTPUT”

    Echo “Live HTTP subdomains saved to: $OUTPUT_DIR/$LIVE_HTTP_OUTPUT”

    Echo “Live HTTPS subdomains saved to: $OUTPUT_DIR/$LIVE_HTTPS_OUTPUT”

    Echo “WHOIS data saved to: $OUTPUT_DIR/$WHOIS_OUTPUT”

    Echo “Shared IPs detected saved to: $OUTPUT_DIR/shared_ips.txt”

    Echo “Report generated at: $OUTPUT_DIR/report.csv”

    Echo “HTML report generated at: $OUTPUT_DIR/report.html”

}

run_enumeration() {
    setup_database
    dns_query
    sublist3r_enumeration
    amass_enumeration
    dnsrecon_enumeration
    massdns_enumeration
    brute_force_enumeration
    merge_results
    resolve_subdomains
    check_live_http_https
    generate_reports
    schedule_task
    log_message "Subdomain enumeration completed."
}

run_enumeration
log_message "Subdomain enumeration process completed."
