#!/usr/bin/env bash
# This application goes through each TCP/IP model layer to discover the breakpoint
# 1. Test Network Access Layer
#     a. Check default gateway exists.
#     b. `ping` default gateway to check if local firewall/disconnect is the problem.
#     c. Check `arp -a` to see if there are local, discovered devices.
# 2. Test Network Layer
#     a. Check to make sure routing table has entries.
#     b. Check for IP-based communication by pinging Google (should always be up) or given IP.
#     c. Test large packets by sending a max size packets
#     d. If an error occurs -> trace route and show where the error occurred to output.
# 3. Test Transport Layer
#     a. Test End-to-End for TCP with Test-NetConnection.
# 4. Test Application Layer
#     a. Take input to determine which app protocol (HTTP/HTTPS, TSL/SSL, DNS, SSH).
#     b. Run corresponding application to destination to test whether it is accessible.

# Get args and make sure user inputs are validated
Destination="google.com"
Port=443
Protocol="HTTPS"
while getopts ":d:p:a:" opt; do
    case "${opt}" in 
        d) Destination=${OPTARG} ;;
        p) Port=${OPTARG};;
        a) Protocol=${OPTARG};;
        :) echo "Option -${OPTARG} requires a value"; exit 1;;
        \?) echo "Invalid Flag -${OPTARG}"; exit 1 ;;
    esac
done

Validate_Args () {
    Protocol_Regex='^(HTTP|HTTPS|TLS|SSL|DNS|SSH)$'
    if [ ${Port} -lt 0 ] || [ ${Port} -gt 65535 ]; then
        echo "Invalid Argument (${Port}): Port range is 0-65535.">&2
        exit 1
    elif ! [[ "${Protocol}" =~ ${Protocol_Regex} ]]; then
        echo "Invalid Argument (${Protocol}): Protocol must be HTTP, HTTPS, TSL, SSL, DNS, or SSH">&2
        exit 1
    fi
}

Validate_Args

Is_IP() {
    if [[ $# -ne 1 ]]; then
        echo "Function 'Is_IP' requires 1 argument - The Address.">&2
        return 1
    fi
    local Address=$1
    if [[ $Address =~ "^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])$" ]]; then
        return 0
    else
        return 1
    fi
}

# Set Default Gateway or null if not found
Default_Gateway=$(  
    ip route show default |
    grep "default" |
    awk '{print $3}'
)

Ping_Regex='[1]?[0-9][0-9]% packet loss'

# Test 1 - Gets Default Gateway using ipconfig and runs a ping test
Test-Network-Access-Layer () {
    if ! [[ "${Default_Gateway}" ]]; then
        echo "Error in Network Access Layer: No Default Gateway found.">&2
        exit 1
    fi

    # Test arp table contains Default Gateway and it isnt "ff-ff-ff-ff-ff-ff" (default value)
    local Arp_Output=$(arp -a | grep -E "${Default_Gateway}")
    local Arp_Regex=' ([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2} '
    if [[ ! "${Arp_Output}" =~ ${Arp_Regex} ]] || 
        [[ "${Arp_Output:l}" =~ "ff:ff:ff:ff:ff:ff" ]]; then
        echo "Error in Network Access Layer: Invalid/Missing Default Gateway MAC Address in ARP table.">&2
        exit 1
    fi

    # Test ping on Default Gateway
    local Ping_Output=$(ping -c 10 "${Default_Gateway}")
    if [[ "${Ping_Output}" =~  ${Ping_Regex} ]]; then
        echo "Error in Network Access Layer: Default Gateway ping failed.">&2
        exit 1
    fi
    echo "Network Access Layer Test Successful."
}

# Test 2 - Test messaging across networks
Test-Network-Layer () {
    # Check route list - Make sure default route is the Default Gateway (0.0.0.0/0 matches all)
    local Route_Table=$(route | grep default)
    if ! [[ "${Route_Table}" =~ "_gateway" ]]; then
        echo "Error in Network Layer: Default Gateway not Default Route.">&2
        exit 1
    fi


    # Test `ping` on destination
    local Ping_Output=$(ping -c 10 "${Destination}")
    if [[ "${Ping_Output}" =~  ${Ping_Regex} ]]; then
        echo "Tracing Route.">&2
        traceroute "${Destination}"
        echo "Error in Network Access Layer: Default Gateway ping failed.">&2
        exit 1
    fi

    # Test Large Packets
    local Large_Ping_Output=$(ping -D -s 1472 -c 10 "${Destination}")
    if [[ "${Large_Ping_Output}" =~  ${Ping_Regex} ]]; then
        echo "Tracing Route.">&2
        traceroute "${Destination}"
        echo "Warning in Network Layer: Large file message failed.">&2
        return
    fi
    echo "Network Layer Test Successful."
}

# Test 3 - Test end-to-end TCP messaging
Test-Transport-Layer () {
    # Test TCP message to destination
    local Netcat_Output=$(nc -zv -w 5 "${Destination}" "${Port}" 2>&1)
    local Netcat_Regex='Connection to .* succeeded!$'
    if ! [[ "${Netcat_Output}" =~ ${Netcat_Regex} ]] &&
        ! [[ "${Netcat_Output}" =~ ' open$' ]]; then
        echo "Error in Transport Layer: Connection test failed.">&2
        exit 1
    fi
    echo "Transport Layer Test Successful."
}

Get-URI () {
    if [[ $# -ne 2 ]]; then
        echo "Function 'Get-URI' requires 2 argument - Prefix and Address.">&2
        exit 1
    fi
    local Prefix=$1
    local Address=$2
    if (( $(Is_IP ${Address}) )); then
        echo ${Address}
    fi
    echo "${Prefix}://${Destination}"
}

# Test 4 - Test specific app protocol
Test-Application-Layer () {
    # Test Protocol
    {
        case $Protocol in
            "HTTP")
                local Uri=$(Get-URI "http" "${Destination}")
                curl -v "${Uri}" &>/dev/null
                local Status=$?
                if [ $? -ne 0 ]; then
                    echo "Error in Application Layer: Web Request Failed - ${Status}.">&2
                    exit 1
                fi
            ;;
            "HTTPS")
                local Uri=$(Get-URI "https" "${Destination}")
                curl -v "${Uri}" &>/dev/null
                local Status=$?
                if [ $? -ne 0 ]; then
                    echo "Error in Application Layer: Web Request Failed - ${Status}.">&2
                    exit 1
                fi
            ;;
            "TLS"|"SSL")
                echo "Q" | timeout 5s openssl s_client -connect ${Destination}:${Port} &>/dev/null
                local Response=$?
                if ! [ "${Response}" -eq 0 ]; then
                    echo "openssl error: ${Response}"
                    exit 1
                fi
            ;;
            "DNS")
                nslookup ${Destination} &>/dev/null
                local Response=$?
                if ! [ "${Response}" -eq 0 ]; then
                    echo "nslookup error: ${Response}"
                    exit 1
                fi
            ;;
            "SSH")
                ssh -v -o ConnectTimeout=5 ${Destination}
                local Response=$?
                if ! [ "${Response}" -eq 0 ]; then
                    echo "ssh error: ${Response}"
                    exit 1
                fi
            ;;
        esac
    } || {
        if catch *; then
            echo "Error in Application Layer: $CAUGHT">&2
            exit 1
        fi
    }
    echo "Application Layer Test Successful."
}

echo "Starting Connectivity Tests"
Test-Network-Access-Layer
Test-Network-Layer
Test-Transport-Layer
Test-Application-Layer