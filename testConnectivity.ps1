# This application goes through each TCP/IP model layer to discover the breakpoint
# 1. Test Network Access Layer
#     a. Run `ipconfig` and check default gateway exists.
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

[CmdletBinding(PositionalBinding=$false)]
param (
    [string]$Destination="google.com",
    [ValidateRange(0, 65535)]
    [int]$Port=443,
    [ValidateSet("HTTP", "HTTPS", "TSL", "SSL", "DNS", "SSH")]
    [string]$Protocol="HTTPS"
)

function Is_IP {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address
    )

    return $Address -match "^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d|\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]\d|\d)$"
}

# Set Default Gateway or null if not found
$Default_Gateway = ipconfig |
    findstr("Default Gateway") |
    Select-String -Pattern "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" |
    ForEach-Object { $_.Matches.Value } |
    Select-Object -First 1 | % ToString

# Test 1 - Gets Default Gateway using ipconfig and runs a ping test
function Test-Network-Access-Layer{
    if (-not $Default_Gateway) {
        throw "Error in Network Access Layer: No Default Gateway found."
    }

    # Test arp table contains Default Gateway and it isnt "ff-ff-ff-ff-ff-ff" (default value)
    $Arp_Output = arp -a | findstr($Default_Gateway)
    if (
        -not ($Arp_Output -match "([A-Za-z\d]{2}-){5}[A-Za-z\d]") -or 
        $Arp_Output -match "(?i)ff-ff-ff-ff-ff-ff"
    ) {
        throw "Error in Network Access Layer: Invalid/Missing Default Gateway MAC Address in ARP table."
    }

    # Test ping on Default Gateway
    $Ping_Output = ping $Default_Gateway
    if (-not ($Ping_Output -match  "Reply from ($Default_Gateway)")) {
        throw "Error in Network Access Layer: Default Gateway ping failed."
    }
    echo "Network Access Layer Test Successful."
    # echo $Ping_Output
    # $failed_ping = ping 255.255.255.1
    # $false_ping = ping 255.255.255.255
    # if ($false_ping -match  "Reply from ($Default_Gateway)") {
    #     echo "false_ping"
    # }
    # echo $false_ping
    # if ($failed_ping -match  "Reply from ($Default_Gateway)") {
    #     echo "failed_ping"
    # }
    # echo $failed_ping
}

# Test 2 Test messaging across networks
function Test-Network-Layer {
    # Check route list - Make sure default route is the Default Gateway (0.0.0.0/0 matches all)
    $Default_Route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Select-Object NextHop -ExpandProperty NextHop
    if ($Default_Route -ne $Default_Gateway) {
        throw "Error in Network Layer: Default Gateway not Default Route."
    }

    # Test ping on destination
    $Ping_Output = ping ${Destination}
    if (-not ($Ping_Output -match  "Reply from ")) {
        echo "Tracing Route"
        tracert ${Destination} | echo
        throw "Error in Network Layer: Destination ping failed."
    }

    # Test large packet ping
    $Large_Ping_Output = ping -f -l 1472 ${Destination}
    if (-not ($Ping_Output -match "Reply from ")) {
        echo "Warning in Network Layer: Large file message failed."
        echo "Tracing Route"
        tracert ${Destination} | echo
        return
    }
    echo "Network Layer Test Successful."
}

# Test 3 Test end-to-end TCP messaging
function Test-Transport-Layer {
    # Test TCP message to {destination}
    $Message_Succeeded = Test-NetConnection -ComputerName ${Destination} -Port $Port |
        Select-Object -ExpandProperty TcpTestSucceeded
    if (-not $Message_Succeeded) {
        throw "Error in Transport Layer: Connection test failed."
    }
    echo "Transport Layer Test Successful."
}

function Get-URI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prefix,
        [Parameter(Mandatory=$true)]
        [string]$Address
    )

    if (Is_IP ${Destination}) {
        return ${Destination}
    }
    return "${Prefix}://${Destination}"
}

# Test 4 Test specific app protocol
function Test-Application-Layer {
    # Test Protocol
    try {
        switch($Protocol) {
            "HTTP" {
                $Uri = Get-URI "http" ${Destination}
                $Response = Invoke-WebRequest -Uri ${Destination}
                $Status_Code = $Response.StatusCode
                if (-not ($Status_Code.ToString() -match "2\d\d")) {
                    $Status_Description = $Response.StatusDescription
                    throw "Error in Application Layer: Web Request Failed: $Status_Code - $Status_Description"
                }
            }
            "HTTPS" {
                $Uri = Get-URI "https" ${Destination}
                $Response = Invoke-WebRequest -Uri ${Destination}
                $Status_Code = $Response.StatusCode
                if (-not ($Status_Code.ToString() -match "2\d\d")) {
                    $Status_Description = $Response.StatusDescription
                    throw "Error in Application Layer: Web Request Failed: $Status_Code - $Status_Description"
                }
            }
            "TLS" {
                openssl s_client -connect ${Destination}:$Port
            }
            "SSL" {
                openssl s_client -connect ${Destination}:$Port
            }
            "DNS" {
                nslookup ${Destination}
            }
            "SSH" {
                ssh -v ${Destination}
            }
        }
    } catch {
        throw "Error in Application Layer: $_.Exception.Message"
    }
    echo "Application Layer Test Successful."
}

echo "Starting Connectivity Tests"
Test-Network-Access-Layer
Test-Network-Layer
Test-Transport-Layer
Test-Application-Layer