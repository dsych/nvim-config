#!/usr/bin/env bash
# tmux-region-lookup.sh - Fuzzy search AWS regions
# Searchable by: airport code, region code, public name, partition, country, prefix
# Selected region code is copied to tmux buffer + system clipboard
# Source: https://w.amazon.com/bin/view/Region%28AWS%29

export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

# Format: AIRPORT|PARTITION|REGION_CODE|PREFIX|PUBLIC_NAME|COUNTRY|ZONES
REGIONS='IAD|aws|us-east-1|USE1|US East (N. Virginia)|USA|us-east-1[abcdef]
DUB|aws|eu-west-1|EU|Europe (Ireland)|IRE|eu-west-1[abc]
SFO|aws|us-west-1|USW1|US West (N. California)|USA|us-west-1[abc]
SIN|aws|ap-southeast-1|APS1|Asia Pacific (Singapore)|SING|ap-southeast-1[abc]
NRT|aws|ap-northeast-1|APN1|Asia Pacific (Tokyo)|JPN|ap-northeast-1[abcd]
PDT|aws-us-gov|us-gov-west-1|UGW1|AWS GovCloud (US-West)|USA|us-gov-west-1[abc]
PDX|aws|us-west-2|USW2|US West (Oregon)|USA|us-west-2[abcd]
GRU|aws|sa-east-1|SAE1|South America (Sao Paulo)|BRA|sa-east-1[abc]
SYD|aws|ap-southeast-2|APS2|Asia Pacific (Sydney)|AUS|ap-southeast-2[abc]
BJS|aws-cn|cn-north-1|CNN1|China (Beijing)|CHN|cn-north-1[ab]
FRA|aws|eu-central-1|EUC1|Europe (Frankfurt)|DEU|eu-central-1[abc]
ICN|aws|ap-northeast-2|APN2|Asia Pacific (Seoul)|KOR|ap-northeast-2[abcd]
BOM|aws|ap-south-1|APS3|Asia Pacific (Mumbai)|IND|ap-south-1[abc]
CMH|aws|us-east-2|USE2|US East (Ohio)|USA|us-east-2[abc]
YUL|aws|ca-central-1|CAN1|Canada (Central)|CAN|ca-central-1[ab]
LHR|aws|eu-west-2|EUW2|Europe (London)|GBR|eu-west-2[abc]
ZHY|aws-cn|cn-northwest-1|CNW1|China (Ningxia)|CHN|cn-northwest-1[abc]
CDG|aws|eu-west-3|EUW3|Europe (Paris)|FRA|eu-west-3[abc]
KIX|aws|ap-northeast-3|APN3|Asia Pacific (Osaka)|JPN|ap-northeast-3[a]
OSU|aws-us-gov|us-gov-east-1|UGE1|AWS GovCloud (US-East)|USA|us-gov-east-1[abc]
ARN|aws|eu-north-1|EUN1|Europe (Stockholm)|SWE|eu-north-1[abc]
HKG|aws|ap-east-1|APE1|Asia Pacific (Hong Kong)|CHN|ap-east-1[abc]
BAH|aws|me-south-1|MES1|Middle East (Bahrain)|BAH|me-south-1[abc]
MXP|aws|eu-south-1|EUS1|Europe (Milan)|ITA|eu-south-1[abc]
CPT|aws|af-south-1|AFS1|Africa (Cape Town)|ZA|af-south-1[abc]
CGK|aws|ap-southeast-3|APS4|Asia Pacific (Jakarta)|IDN|ap-southeast-3[abc]
DXB|aws|me-central-1|MEC1|Middle East (UAE)|UAE|me-central-1[abc]
ZRH|aws|eu-central-2|EUC2|Europe (Zurich)|CHE|eu-central-2[abc]
ZAZ|aws|eu-south-2|EUS2|Europe (Spain)|ESP|eu-south-2[abc]
HYD|aws|ap-south-2|APS5|Asia Pacific (Hyderabad)|IND|ap-south-2[abc]
MEL|aws|ap-southeast-4|APS6|Asia Pacific (Melbourne)|AUS|ap-southeast-4[abc]
TLV|aws|il-central-1|ILC1|Israel (Tel Aviv)|ISR|il-central-1[abc]
YYC|aws|ca-west-1|CAN2|Canada West (Calgary)|CAN|ca-west-1[abc]
KUL|aws|ap-southeast-5|APS7|Asia Pacific (Malaysia)|MY|ap-southeast-5[abc]
BKK|aws|ap-southeast-7|APS9|Asia Pacific (Thailand)|THA|ap-southeast-7[abc]
QRO|aws|mx-central-1|MXC1|Mexico (Central)|MX|mx-central-1[abc]
TPE|aws|ap-east-2|APE2|Asia Pacific (Taipei)|ROC|ap-east-2[abc]
AKL|aws|ap-southeast-6|APS8|Asia Pacific (New Zealand)|NZ|ap-southeast-6[abc]'

# Build display lines: "IAD  aws          us-east-1         USE1  US East (N. Virginia)         USA  us-east-1[abcdef]"
display=$(echo "$REGIONS" | awk -F'|' '{
    printf "%-4s  %-12s %-18s %-5s %-35s %-5s %s\n", $1, $2, $3, $4, $5, $6, $7
}')

header=$(printf "%-4s  %-12s %-18s %-5s %-35s %-5s %s" \
    "CODE" "PARTITION" "REGION" "PFX" "NAME" "CTRY" "ZONES")

selected=$(echo "$display" | fzf \
    --header="$header" \
    --prompt="Region> " \
    --reverse \
    --no-multi \
    --ansi \
    --height=100% \
    --border=none \
    --info=inline)

[ -z "$selected" ] && exit 0

# Extract region code (3rd column)
region_code=$(echo "$selected" | awk '{print $3}')

# Copy via tmux load-buffer -w (sends OSC 52 to outer terminal, works from popups)
echo -n "$region_code" | tmux load-buffer -w -

# Show confirmation
echo "Copied: $region_code"
sleep 0.6
