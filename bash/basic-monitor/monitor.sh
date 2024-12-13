#!/bin/bash

# ANSI color codes
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BOLD="\e[1m"
RESET="\e[0m"

# Store ASCII art pieces
read -r -d '' ART1 << 'EOF'
    /\___/\
   (  o o  )
   (  =^=  )
    (-----|)
     |___|_)
EOF

read -r -d '' ART2 << 'EOF'
     ,____,
    (  || )
     )  =  )
    (  _|  )
     |__|__)
    /_/_/_/
EOF

read -r -d '' ART3 << 'EOF'
    |\_/|
    |q p|   /}
    ( 0 )"""\\
    |"^"`    |
    ||_/=\\__|
EOF

read -r -d '' ART4 << 'EOF'
     /\___/\
    ( o   o )
    (  =^=  )
     (    )
      |  |
     (__|__)
EOF

read -r -d '' ART5 << 'EOF'
    ▄▄▄▄▄▄▄▄▄▄
    █        █
    █  ●  ●  █
    █   ▲    █
    █  ▔▔▔   █
    ▀▀▀▀▀▀▀▀▀▀
EOF

# Function to hide cursor
hide_cursor() {
    tput civis
}

# Function to show cursor
show_cursor() {
    tput cnorm
}

# Save initial screen state and hide cursor
save_screen() {
    tput smcup
    hide_cursor
}

# Restore screen and cursor
restore_screen() {
    show_cursor
    tput rmcup
}

# Cleanup function
cleanup() {
    restore_screen
    exit 0
}

# Set up trap for clean exit
trap cleanup SIGINT SIGTERM

# Function to position cursor and print with color
print_at() {
    local row=$1
    local col=$2
    shift 2
    tput cup $row $col
    echo -e "$@"
}

# Function to create bar graph
create_bar() {
    local percentage=$1
    local width=30
    local filled=$(printf "%.0f" $(echo "$percentage * $width / 100" | bc -l))
    local empty=$((width - filled))
    
    printf "["
    for ((i=0; i<filled; i++)); do
        printf "#"
    done
    for ((i=0; i<empty; i++)); do
        printf "."
    done
    printf "] %3d%%" "$percentage"
}

# Function to get random ASCII art with random color
get_random_art() {
    local arts=("$ART1" "$ART2" "$ART3" "$ART4" "$ART5")
    local colors=("$GREEN" "$YELLOW" "$RED" "$BLUE" "$CYAN" "$MAGENTA")
    local random_color=${colors[$RANDOM % ${#colors[@]}]}
    local random_art=${arts[$RANDOM % ${#arts[@]}]}
    echo -e "${random_color}${random_art}${RESET}"
}

# Store the random art at startup
CURRENT_ART=$(get_random_art)

# Function to draw a box border
draw_border() {
    local width=$(tput cols)
    printf "+%*s+\n" $((width-2)) | tr ' ' '-'
    for i in $(seq 1 $1); do
        printf "|%*s|\n" $((width-2)) ""
    done
    printf "+%*s+\n" $((width-2)) | tr ' ' '-'
}

# Function to display header with art
show_header() {
    local width=$(tput cols)
    local title="System Monitoring Dashboard"
    local padding=$(( (width - ${#title}) / 2 ))
    print_at 1 $padding "${BOLD}${BLUE}$title${RESET}"
    print_at 2 2 "$(date "+%Y-%m-%d %H:%M:%S")"
    
    # Fixed art position further to the right
    local art_padding=85
    
    # Display ASCII art on the right, starting from row 2 instead of 1
    local row=3
    while IFS= read -r line; do
        print_at $row $art_padding "$line"
        ((row++))
    done <<< "$CURRENT_ART"
}

# Function to display logged in users
show_users() {
    # Start users section at row 8 (after art typically ends)
    local users=$(who | awk '{print $1}' | sort -u | tr '\n' ' ')
    print_at 8 2 "${BOLD}${GREEN}=== Users ===${RESET}"
    print_at 9 2 "${GREEN}Currently logged in: $users${RESET}"
    print_at 10 2 "${GREEN}Total users: $(echo "$users" | wc -w)${RESET}"
}

# Function to display CPU usage
show_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | awk '{printf "%.1f", $1}')
    local cpu_color=$BLUE
    
    print_at 12 2 "${BOLD}${cpu_color}=== CPU Usage ===${RESET}"
    print_at 13 2 "${cpu_color}$(create_bar ${cpu_usage%.*})${RESET}"
    print_at 14 2 "${BOLD}${cpu_color}Top Processes${RESET}"
    
    local row=15
    ps aux --sort=-%cpu | head -4 | awk 'NR>1 {printf "%-12s %5.1f%%\n", $11, $3}' | while read line; do
        print_at $row 2 "${cpu_color}> $line${RESET}"
        ((row++))
    done
    
    print_at 19 2 "${cpu_color}* Load Average: $(uptime | awk -F'load average:' '{print $2}')${RESET}"
}

# Function to display memory usage
show_memory() {
    local mem_info=$(free | awk 'NR==2{printf "%.1f %.1f", $3/$2*100, $2/1024/1024}')
    local mem_percent=$(echo $mem_info | awk '{print $1}')
    local mem_color=$MAGENTA
    
    print_at 21 2 "${BOLD}${mem_color}=== Memory Usage ===${RESET}"
    print_at 22 2 "${mem_color}$(create_bar ${mem_percent%.*})${RESET}"
    
    local swap_info=$(free | awk 'NR==3{printf "%.1f", $3/$2*100}')
    [ ! -z "$swap_info" ] && print_at 23 2 "${mem_color}> Swap Usage: $(create_bar ${swap_info%.*})${RESET}"
}

# Function to get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | tr -d '%'
}

# Function to display disk usage
show_disk() {
    local disk_color=$YELLOW
    local disk_usage=$(get_disk_usage)
    
    print_at 25 2 "${BOLD}${disk_color}=== Disk Usage (/) ===${RESET}"
    print_at 26 2 "${disk_color}$(create_bar $disk_usage)${RESET}"
}

# Function to get network stats
get_network_stats() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$interface" ]; then
        echo "0 0"
        return
    fi
    cat /proc/net/dev | grep "$interface:" | awk '{print $2,$10}'
}

# Function to format network rate
format_network_rate() {
    local bytes=$1
    if [ $bytes -lt 0 ]; then
        bytes=0
    fi
    if [ $bytes -gt 1073741824 ]; then
        echo "$(($bytes/1073741824))G"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(($bytes/1048576))M"
    elif [ $bytes -gt 1024 ]; then
        echo "$(($bytes/1024))K"
    else
        echo "${bytes}B"
    fi
}

# Previous network values for calculating rate
previous_rx=0
previous_tx=0

# Function to display network usage
show_network() {
    local net_color=$GREEN
    local stats=($(get_network_stats))
    local rx=${stats[0]:-0}
    local tx=${stats[1]:-0}
    
    local rx_rate=$((rx - previous_rx))
    local tx_rate=$((tx - previous_tx))
    
    previous_rx=$rx
    previous_tx=$tx
    
    print_at 28 2 "${BOLD}${net_color}=== Network I/O ===${RESET}"
    print_at 29 2 "${net_color}↓ $(format_network_rate $rx_rate)/s  ↑ $(format_network_rate $tx_rate)/s${RESET}"
}

# Function to display system information
show_system_info() {
    local sys_color=$CYAN
    print_at 31 2 "${BOLD}${sys_color}=== System Info ===${RESET}"
    print_at 32 2 "${sys_color}> Kernel: $(uname -r)${RESET}"
    print_at 33 2 "${sys_color}> Uptime: $(uptime -p)${RESET}"
}

# Function to display SSH sessions
show_ssh() {
    print_at 35 2 "${BOLD}${CYAN}=== SSH Sessions ===${RESET}"
    local row=36
    who | grep pts | awk '{printf "%-12s %-15s %s\n", $1, $5, $3}' | while read line; do
        print_at $row 2 "${CYAN}> $line${RESET}"
        ((row++))
    done
}

# Initialize screen
save_screen
clear

# Draw initial border (won't be redrawn)
draw_border 40

# Main loop
while true; do
    show_header
    show_users
    show_cpu
    show_memory
    show_disk
    show_network
    show_system_info
    show_ssh
    sleep 1.5
done