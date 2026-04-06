# File Explorer

This repo is used to store different network tests to determine where conection problems occur.

## Table of Contents
 - [Usage](#usage)
 - [Testing Connectivity](#testing-connectivity)
 - [General Info](#general-info)
 - [1. Physical Layer](#layer-1-physical-layer)
 - [2. Data Link Layer](#layer-2-data-link-layer)
 - [3. Network Layer](#layer-3-network-layer)
 - [4. Transport Layer](#layer-4-transport-layer)
 - [5. Session Layer](#layer-5-session-layer)
 - [6. Presentation Layer](#layer-6-presentation-layer)
 - [7. Application Layer](#layer-7-application-layer)

## Usage
Allowed Protocols are "HTTP", "HTTPS", "TSL", "SSL", "DNS", "SSH".
Default values are Destination - 'google.com', Port - 443, Protocol - "HTTPS". 

***Port is only used for SSL/TLS tests.***
### Windows
```powershell
./testConnectivity.ps1 -Destination {Destination} -Port {Port} -Protocol {Protocol}
``` 
### Mac
```zsh
./testConnectivity.zsh -Destination {Destination} -Port {Port} -Protocol {Protocol}
```
### Linux
```bash
./testConnectivity.sh -d {Destination} -p {Port} -a {Protocol}
```

## Testing Connectivity
This guide follows TCP/IP model, since that is the actual model used.
Nmap can be downloaded used to see discoverable networks in the network and transport layers.
WireShark can be downloaded and used to detect incoming and outgoing requests which can debug by checking protocol messages (ARP, TCP, etc).
### Jump To
 - [Network Access Layer](#network-access-layer)
 - [Network Layer](#network-layer)
 - [Transportation Layer](#transport-layer)
 - [Application Layer](#application-layer)
### Network Access Layer:
Ensure wires are plugged in, hardware is turned on and you are connected to the internet.
```bash
# This checks to make sure you are connected
# Windows
ipconfig
# Mac
ifconfig
# Linux (specify with eth0, wlan0, etc.)
ip link show
```
Make sure device can communicate with local devices and has MAC/physical address.
```bash
# Make sure you have physical address
arp -a
# Ping default gateway to make sure it is accessible
# Default gateway should be first internet address
# Can also be found with ipconfig and maybe the layer 1 tests
# Windows
ping <default_gateway_ip>
# Mac
ping -c 4 <default_gateway_ip>
# Linux
ping -c 4 <default_gateway_ip>
```

### Network Layer:
#### Ensure you have IP-based communication:
```bash
# Windows
ping <destination_ip>
# Mac
ping -c 4 <destination_ip>
# Linux
ping -c 4 <destination_ip>
```
Check where the packet dies:
```bash
# Windows
tracert <destination_ip>
# Mac
traceroute <destination_ip>
# Linux
traceroute <destination_ip>
```
#### Verify routing table exists
```bash
# Windows
route print
# Mac
netstat -rn
# Linux
ip route
```
#### Large Package Test
Failure indicates maximum transmission unit (MTU) mismatch.
If failure, try reducing size to determine the limit.

1472 = 1500 bytes (standard size) - 28 bytes (IP/ICMP header)

Common issues:
 - VPN/tunnels overhead
 - Point to Point Protocol over Ethernet (PPPoE) requires lower MTU
 - Misconfigured network devices
```bash
# Windows
ping -f -l 1472 <destination_ip>
# Mac
ping -D -s 1472 <destination_ip>
# Linux
ping -M do -s 1472 <destination_ip>
```

### Transport Layer:
#### Verify End-to-End using TCP/UDP ports:
```bash
# Windows (PowerShell)
Test-NetConnection -ComputerName <destination_ip> -Port <port>
# Mac - (Netcat)
# TCP
nc -zv <destination_ip/hostname> <port>
# UDP
nc -zvu <destination_ip/hostname> <port>
# Linux - (Netcat)
# TCP
nc -zv <destination_ip/hostname> <port>
# UDP
nc -zvu <destination_ip/hostname> <port>
```
With tcptraceroute/tracetcp (Require download)
```bash
# Windows
tracetcp <destination_ip/hostname>:<port>
# Mac
tcptraceroute <destination_ip/hostname> <port>
# Linux
tcptraceroute <destination_ip/hostname> <port>
```
#### Trouble Receiving Messages
If there is trouble receiving messages, you can check port usage.
```bash
# Windows
netstat -ano | findstr :<port>
# Mac and Linux
netstat -tuln | grep :<port>
# Linux (Socket check)
ss -tuln sport = :<port>
```

### Application Layer
To test application layer, test software that runs at the application level:
#### Port Specific Testing
To test specific ports, transport layers can be used as well as:
```bash
telnet <destination_ip/hostname> <port>
```
#### HTTP/HTTPS Testing
```bash
# Windows Specific
Invoke-WebRequest -Uri <url> -Verbose
# Windows, Mac, Linux
curl -v <url>
```
#### TSL/SSL
```bash
# Mac and Linux, can be downloaded for Windows
openssl s_client -connect <destination_ip/hostname>:<port>
```
#### DNS
```bash
# Windows, Mac, Linux
nslookup <destination_ip/hostname>
```
#### SSH
```bash
ssh -v <destination_ip/hostname>
```

## General Info
![OSI Model](https://asmed.com/wp-content/uploads/2016/03/OSI-Model-3-29-17-website.jpg)

The Open Systems Interconnection(OSI) model is a theoretical model for how the internet works. The actual model for how the internet works is the TCP/IP model. This model combines layers 1, 2 into the Network Access Layer and layers 5, 6, 7 into the Application Layer.

![TCP/IP Model](https://media.geeksforgeeks.org/wp-content/uploads/20230417045622/OSI-vs-TCP-vs-Hybrid-2.webp)

## Layer 1: Physical Layer
### Definition
This layer defines the physical or electrical connection:
 - physical transmission medium (copper or fiber optic cable, radio frequency, etc.)
 - transmission mode (simplex, duplex, etc.)
 - network topology (bus, mesh, ring, etc.)
 - transmission (digital or analog)

The protocol data unit (PDU) for this layer is bits and this layer does the encoding to bits before sending messages.
### Examples
Examples of this layer are the physical layers of the following (Wireless, Coax, Fiber):
 - Ethernet
 - Wi-Fi
 - Bluetooth

## Layer 2: Data Link Layer
### Definition
The data link layer provides node to node data transfer. This layer possibly detects and corrects errors in the physical layer, such as loss or corrupt frames. The Data Link Layer is split into two layers:
 - Media Access Control(MAC) layer: The MAC layer is responsible for controlling how devices gain access to the physical layer and permissions to transmit. The
 - Logical Link Control(LLC) layer: The LLC layer is responsible for network layer protocols and encapsulating them and error checking/frame synchronization.

The PDU for this layer is Frames.
### Examples
Examples of this layer are the following (These operate in both layers on different levels):
 - Ethernet
 - Wi-Fi
 - Bluetooth

## Layer 3: Network Layer
### Definition
The network layer provides variable length data sequences messaging between nodes on the same network.
This layer translates logical network addresses into the physical machine address. 
Message sending can use intermediate nodes if necessary.
The network layer is responsible for splitting messages that are too long into fragments before sending the message to the data link layer. Fragments are sent independent from each other and reassembled at other nodes. The network layer does not always indicate delivery errors. The PDU for the network layer is Packets.
### Examples
Examples of protocols in this layer:
 - IP
 - ICMP
 - ARP

## Layer 4: Transport Layer
### Definition
The transport layer provides the means of transporting variable length sequences via one or more networks. The PDU for the transport layer is segments. This layer is responsible for segmentation, desegmentation, error control, and reliability. Some protocols ensure reliability and some do not. This layer is also responsible for converting data from the application layer to packets.
### Examples
Examples of transport layer protocols:
 - User Datagram Protocol (UDP)
 - Transmission Control Protocol (TCP)

## Layer 5: Session Layer
### Definition
The session layer is responsible for establishing and closing connections between computers. 
This layer provides the following:
 - Simplex and duplex operation
 - Checkpointing and restarting procedures
 - Graceful shutdowns

This layer is usually implemented explicitly in applications that use remote procedure calls (RPC).
The PDU is data, which is a generic to represent compress, encrypted, etc. information being sent.
### Examples
Examples of session layer protocols:
 - RPC, gRPC
 - APIs
 - SOCK (Sockets)

## Layer 6: Presentation Layer
### Definition
The presentation layer, sometimes called the syntax layer, is responsible for data compression, readability, encryption, etc. 
This layer ensures that data being sent is secure and data being received is readable.
### Examples
Examples of presentation layer protocols:
 - Secure Socket Layer (SSL)
 - Transport Layer Security (TLS)

## Layer 7: Application Layer
### Definition
The application layer is the layer the user directly interacts with.
Everything in this layer is application-specific.
This layer is responsible for the following:
 - Identifying communication partners
 - Determining resource availability
 - Synchronizing communication
### Examples
Examples of application layer protocols:
 - HyperText Transfer Protocol/Secure (HTTP/HTTPS)
 - File Transfer Protocol (FTP)
 - Domain Name System (DNS)