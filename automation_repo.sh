#!/bin/bash

# Get yesterday's date in the format YYYYMMDD
dt=$(date +%Y%m%d)
dtt=$(date +%d-%m-%Y)
# Define the servers you want to connect to
servers=("plsmsgw243" "plsmsgw244" "plsmsgw033" "plsmsgw047")

# Initialize empty file to store the results for unique counts
> WAVE_Master_Unique.txt

# Loop through each server and fetch unique count data
for server in "${servers[@]}"; do
    ssh -n ecp@$server "zcat /data/csms/cdrs/push/push.cdr.$dt.* | grep -i '1607100000000195422' | awk -F '|' '{if(\$9 == \$10) print \$28}' | sort | uniq -c" >> WAVE_Master_Unique.txt
done

# Declare an associative array to hold the counts for different statuses
declare -A status_counts=(
    ["Submit-Success"]=0
    ["DELIVERED"]=0
    ["Delivery-Timeout"]=0
    ["EXPIRED"]=0
    ["Submit-Failed"]=0
    ["UNDELIVERABLE"]=0
)

# Process the unique counts and store them in the associative array
while read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    campaign=$(echo "$line" | awk '{print $2}')

    # Based on the campaign name, store the count in the respective category
    case "$campaign" in
        "Submit-Success") status_counts["Submit-Success"]=$((status_counts["Submit-Success"] + count)) ;;
        "DELIVERED") status_counts["DELIVERED"]=$((status_counts["DELIVERED"] + count)) ;;
        "Delivery-Timeout") status_counts["Delivery-Timeout"]=$((status_counts["Delivery-Timeout"] + count)) ;;
        "Submit-Failed") status_counts["Submit-Failed"]=$((status_counts["Submit-Failed"] + count)) ;;
        "UNDELIVERABLE") status_counts["UNDELIVERABLE"]=$((status_counts["UNDELIVERABLE"] + count)) ;;
    esac
done < WAVE_Master_Unique.txt

# Calculate EXPIRED using the formula: Submit-Success - (DELIVERED + Delivery-Timeout + Submit-Failed + UNDELIVERABLE)
status_counts["EXPIRED"]=$((status_counts["Submit-Success"] - (status_counts["DELIVERED"] + status_counts["Delivery-Timeout"] + status_counts["Submit-Failed"] + status_counts["UNDELIVERABLE"])))

# Calculate the Success% based on the formula: (DELIVERED/Submit-Success) * 100
if (( status_counts["Submit-Success"] > 0 )); then
    success_percentage=$(awk "BEGIN { printf \"%.2f\", (${status_counts["DELIVERED"]} / ${status_counts["Submit-Success"]}) * 100 }")
else
    success_percentage=0
fi

# Create a CSV file with the required format
csv_file="/data/FTP_Report/WAVE_Unique_Report_TataFiber_$dt.csv"

# Write headers to the CSV file
echo "Date,Submit-Success,DELIVERED,Delivery-Timeout,EXPIRED,Submit-Failed,UNDELIVERABLE,Success%" > "$csv_file"

# Write the counts and success percentage to the CSV file
echo "$dtt,${status_counts["Submit-Success"]},${status_counts["DELIVERED"]},${status_counts["Delivery-Timeout"]},${status_counts["EXPIRED"]},${status_counts["Submit-Failed"]},${status_counts["UNDELIVERABLE"]},$success_percentage" >> "$csv_file"

# Send the report via email with attachment
echo -e "Dear All,\n\nPlease find attached the report for $dt on the XML Unique traffic for TataPlay." | \
mail -s "WAVE Unique Traffic Report - $dt" -a "$csv_file" arvind.sharma@comviva.com

# Inform the user where the CSV file is saved
echo "Report has been saved to $csv_file and emailed to arvind.sharma@comviva.com."

