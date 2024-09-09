#!/bin/bash

# Create network namespaces
ip netns add red
ip netns add blue

# Create routers
ip netns add r1
ip netns add r2

# Create virtual ethernet interfaces
ip link add ethred type veth peer name ethr1l
ip link add ethr1r type veth peer name ethr2l
ip link add ethr2r type veth peer name ethblue

# Connect interfaces to namespaces
ip link set ethred netns red
ip link set ethr1l netns r1
ip link set ethr1r netns r1 
ip link set ethr2l netns r2
ip link set ethr2r netns r2 
ip link set ethblue netns blue

# Bring up loopback interfaces
ip netns exec red ip link set lo up
ip netns exec blue ip link set lo up
ip netns exec r1 ip link set lo up
ip netns exec r2 ip link set lo up

# Bring up ethernet interfaces
ip netns exec red ip link set ethred up
ip netns exec blue ip link set ethblue up
ip netns exec r1 ip link set ethr1l up
ip netns exec r1 ip link set ethr1r up
ip netns exec r2 ip link set ethr2l up
ip netns exec r2 ip link set ethr2r up

# Assign IP addresses
ip netns exec red ip address add 10.0.0.1/24 dev ethred
ip netns exec r1 ip address add 10.0.0.2/24 dev ethr1l
ip netns exec r1 ip address add 10.0.1.1/24 dev ethr1r
ip netns exec r2 ip address add 10.0.1.2/24 dev ethr2l
ip netns exec r2 ip address add 10.0.2.1/24 dev ethr2r
ip netns exec blue ip address add 10.0.2.2/24 dev ethblue

# Set up default routes
ip netns exec red ip route add default via 10.0.0.2 dev ethred
ip netns exec blue ip route add default via 10.0.2.1 dev ethblue
ip netns exec r1 ip route add default via 10.0.1.2 dev ethr1r
ip netns exec r2 ip route add default via 10.0.1.1 dev ethr2l

# Enable IP forwarding on routers
ip netns exec r1 sysctl -w net.ipv4.ip_forward=1
ip netns exec r2 sysctl -w net.ipv4.ip_forward=1

