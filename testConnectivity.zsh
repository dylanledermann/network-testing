!/usr/bin/env zsh
# This application goes through each TCP/IP model layer to discover the breakpoint
# 1. Test Network Access Layer
#     a. Run `ifconfig` and check default gateway exists.
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
    if (($Port -lt 0)) || (($Port -gt 65535)); then
        echo "Invalid Argument: Port range is 0-65535.">&2
        exit 1
    elif ![[$Protocol =~ "^(HTTP|HTTPS|TSL|SSL|DNS|SSH)$"]]; then
        echo "Invalid Argument: Protocol must be HTTP, HTTPS, TSL, SSL, DNS, or SSH"
        exit 1
    fi
}

Validate_Args

function Is_IP {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address
    )
    if [[$# != 1]]; then
        echo "Function 'Is_IP' requires 1 argument - The Address."
        exit 1
    fi
    Address=$1
    return $Address =~ "^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d|\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d|\d)$"
}

# Set Default Gateway or null if not found
$Default_Gateway = ifconfig |
    findstr("Default Gateway") |
    Select-String -Pattern "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |
    ForEach-Object { $_.Matches.Value } |
    Select-Object -First 1 | % ToString