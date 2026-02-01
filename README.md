
# Emulate TLS Fingerprinting On Network Namespaces Using Ja3/Ja3s & Mercury



## Run Locally

Clone the project



Go to the project directory

```bash
  cd my-project
```

Install dependencies

```bash
  sudo apt install iperf3
  sudo apt install openssl -y
  sudo apt install ja3
  sudo apt install wireshark

```

First Go into sudo mode

```bash
  sudo su
```

Run script to make the network 
```bash
  ./name_s.sh
```

## Screenshots
![Emulate_TLS](https://github.com/Megatrone750/Emulate-TLS-Fingerprinting-on-Network-Namespaces/blob/main/namespace.png)



## Running the Project

open two terminal 

In First Terminal go in Red bash

```bash
  ip netns exec red bash
```
In Second Terminal go in Blue bash

```bash
  ip netns exec blue bash
```
Open wireshark in Red (client) choose ethred interface start capturing packet

```bash
  wireshark 
```

Make Blue as Server using iperf at port 443 
```bash
  iperf3 -s -p 443
```

In Red connect to Blue (server)
```bash
  openssl s_client -connect 10.0.2.2:443
```

wireshark file save in .pcap file format

so in this you will get client hello msg which will helpful for calculating tls fingerprint

using ja3 we can calculate fingerprint

```bash
  ja3.py filename.sh
```




