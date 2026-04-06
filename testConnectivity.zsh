!/usr/bin/env zsh
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
zparseopts -D -A opts -- -Destination -Port -Protocol
Destination=${opts[-Destination]:-"google.com"}
Port=${opts[-Port]:-443}
Protocol=${opts[-Protocol]:-"HTTPS"}

function Validate_Args() {
    if ((${Port} -lt 0)) || ((${Port} -gt 65535)); then
        echo "Invalid Argument: Port range is 0-65535.">&2
        exit 1
    elif ! [[ ${Protocol} =~ "^(HTTP|HTTPS|TSL|SSL|DNS|SSH)$" ]]; then
        echo "Invalid Argument: Protocol must be HTTP, HTTPS, TSL, SSL, DNS, or SSH.">&2
        exit 1
    fi
}

Validate_Args

function Is_IP() {
    if [[ $# -ne 1 ]]; then
        echo "Function 'Is_IP' requires 1 argument - The Address."
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
    grep 'default' |
    awk '{print $3}'
)

# Test 1 - Gets Default Gateway using ipconfig and runs a ping test
function Test-Network-Access-Layer{
    if ! [["${Default_Gateway}"]]; then
        echo "Error in Network Access Layer: No Default Gateway found.">&2
        exit 1
    fi

    # Test arp table contains Default Gateway and it isnt "ff-ff-ff-ff-ff-ff" (default value)
    Arp_Output=$(arp -a | grep -E "${Default_Gateway}")
    if ! [[ "${Arp_Output}" =~ "([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}" ]] || 
        [[ "${Arp_Output:l}" =~ "ff:ff:ff:ff:ff:ff" ]]; then
        echo "Error in Network Access Layer: Invalid/Missing Default Gateway MAC Address in ARP table.">&2
        exit 1
    fi

    # Test ping on Default Gateway
    Ping_Output=$(ping -c 10 "${Default_Gateway}")
    if [[ "${Ping_Output}" =~  "[1]?[0-9][0-9]% packet loss" ]]; then
        echo "Error in Network Access Layer: Default Gateway ping failed.">&2
        exit 1
    fi
    echo "Network Access Layer Test Successful."
}

# Test 2 - Test messaging across networks
function Test-Network-Layer{
    # Check route list - Make sure default route is the Default Gateway (0.0.0.0/0 matches all)
    Route_Table=$(route | grep default)
    if ! [[ "${Route_Table}" =~ "${Default_Gateway}" ]]; then
        echo "Error in Network Layer: Default Gateway not Default Route.">&2
        exit 1
    fi


    # Test `ping` on destination
    Ping_Output=$(ping -c 10 "${Destination}")
    if [[ "${Ping_Output}" =~  "[1]?[0-9][0-9]% packet loss" ]]; then
        echo "Tracing Route.">&2
        traceroute "${Destination}"
        echo "Error in Network Access Layer: Default Gateway ping failed.">&2
        exit 1
    fi

    # Test Large Packets
    Large_Ping_Output=$(ping -D -s 1472 -c 4 "${Destination}")
    if [[ "${Large_Ping_Output}" =~  "[1]?[0-9][0-9]% packet loss" ]]; then
        echo "Tracing Route.">&2
        traceroute "${Destination}"
        echo "Warning in Network Layer: Large file message failed.">&2
        return
    fi
    echo "Network Layer Test Successful."
}

# Test 3 - Test end-to-end TCP messaging
function Test-Transport-Layer{
    # Test TCP message to destination
    Netcat_Output=$(nc -zv -w 5 "${Destination}" "${Port}" 2>&1)
    if ! [[ "${Netcat_Output}" =~ 'Connection to .* succeeded!' ]] &&
        ! [[ "${Netcat_Output}" =~ ' open$' ]]; then
        echo "Error in Transport Layer: Connection test failed.">&2
        exit 1
    fi
    echo "Transport Layer Test Successful."
}

function Get-URI {
    if [[ $# -ne 2 ]]; then
        echo "Function 'Get-URI' requires 2 argument - Prefix and Address.">&2
        exit 1
    fi
    local Prefix=$1
    local Address=$2
    if (( Is_IP ${Address} )); then
        return ${Address}
    fi
    return "${Prefix}://${Destination}"
}

# Test 4 - Test specific app protocol
function Test-Application-Layer{
    # Test Protocol
    {
        case $Protocol in
            "HTTP")
                Uri=$(Get-URI "http" "${Destination}")
                Response=$(curl -v "${Uri}")
                if ! [[ "${Response}" =~ "Connected to ${Destination}" ]]; then
                    echo "Error in Application Layer: Web Request Failed.">&2
                    exit 1
                fi
            ;;
            "HTTPS")
                Uri=$(Get-URI "https" "${Destination}")
                Response=$(curl -v "${Uri}")
                if ! [[ "${Response}" =~ "Connected to ${Destination}" ]]; then
                    echo "Error in Application Layer: Web Request Failed.">&2
                    exit 1
                fi
            ;;
            "TLS"|"SSL")
                openssl s_client -connect ${Destination}:$Port
            ;;
            "DNS")
                nslookup ${Destination}
            ;;
            "SSH")
                ssh -v ${Destination}
            ;;
        esac
    } always {
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