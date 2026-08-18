# Emulate TLS Fingerprinting on Network Namespaces

A small Linux lab that builds two isolated hosts (`red` and `blue`) connected through two virtual routers, then captures a TLS handshake so you can compute **JA3** (client) and **JA3S** (server) fingerprints from a PCAP.

Use this to learn how TLS Client Hello / Server Hello fields are hashed into fingerprints, without needing physical machines or cloud VMs.

## Topology

```
  red (client)          r1 (router)           r2 (router)          blue (server)
  10.0.0.1/24           10.0.0.2 / 10.0.1.1   10.0.1.2 / 10.0.2.1  10.0.2.2/24
       |                      |                     |                    |
    ethred ---------------- ethr1l               ethr2l -------------- ethblue
                            ethr1r ------------- ethr2r
```

| Namespace | Role    | Interface(s)     | Address(es)              | Default gateway |
|-----------|---------|------------------|--------------------------|-----------------|
| `red`     | Client  | `ethred`         | `10.0.0.1/24`            | `10.0.0.2`      |
| `r1`      | Router  | `ethr1l`, `ethr1r` | `10.0.0.2/24`, `10.0.1.1/24` | via `r2`     |
| `r2`      | Router  | `ethr2l`, `ethr2r` | `10.0.1.2/24`, `10.0.2.1/24` | via `r1`     |
| `blue`    | Server  | `ethblue`        | `10.0.2.2/24`            | `10.0.2.1`      |

IP forwarding is enabled on `r1` and `r2`.

## Repository layout

| File | Purpose |
|------|---------|
| `name_s.sh` | Create namespaces, veth pairs, IPs, routes, and forwarding |
| `file_del.sh` | Tear down the four namespaces |
| `ja3.py` | Extract JA3 fingerprints from Client Hello records in a PCAP |
| `ja3s.py` | Extract JA3S fingerprints from Server Hello records in a PCAP |

The Python scripts are based on Salesforce’s [python-ja3](https://github.com/salesforce/ja3) tooling (BSD 3-Clause). They read `.pcap` or `.pcapng` files and, by default, look at TCP port **443**.

## Requirements

- Linux with `iproute2` (`ip netns`, `ip link`, `ip route`)
- Root privileges (network namespaces)
- `openssl` (TLS client)
- `iperf3` (listener on port 443; this is a TCP endpoint, not a full TLS server)
- Wireshark or `tcpdump` (packet capture)
- Python 3 with [`dpkt`](https://github.com/kbandla/dpkt)

Install on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y iproute2 iperf3 openssl wireshark python3 python3-pip
pip3 install dpkt
```

Grant Wireshark capture capability if you do not want to run it as root:

```bash
sudo usermod -aG wireshark "$USER"
# log out and back in
```

## 1. Build the network

```bash
git clone https://github.com/Megatrone750/Emulate-TLS-Fingerprinting-on-Network-Namespaces.git
cd Emulate-TLS-Fingerprinting-on-Network-Namespaces
chmod +x name_s.sh file_del.sh
sudo ./name_s.sh
```

Sanity-check from the host:

```bash
sudo ip netns exec red ping -c 3 10.0.2.2
```

## 2. Capture a TLS handshake

Open **three** shells (all as root, or with `sudo`).

**Terminal A — enter the client namespace**

```bash
sudo ip netns exec red bash
```

**Terminal B — enter the server namespace**

```bash
sudo ip netns exec blue bash
```

**Terminal C — capture on the client interface**

From the host (not inside a namespace), attach Wireshark or tcpdump to `ethred` **inside** `red`. With Wireshark GUI:

```bash
sudo ip netns exec red wireshark
```

Choose interface `ethred` and start capturing. Alternatively:

```bash
sudo ip netns exec red tcpdump -i ethred -w handshake.pcap port 443
```

**On blue (Terminal B)** start a listener on 443:

```bash
iperf3 -s -p 443
```

**On red (Terminal A)** open a TLS client toward blue:

```bash
openssl s_client -connect 10.0.2.2:443
```

`openssl s_client` sends a Client Hello even if the peer is not a real TLS server. Stop the capture after you see the handshake (or the connection fail). Save the capture as a `.pcap` / `.pcapng` file.

> **Note:** `iperf3` does not speak TLS. You may only get a Client Hello (and possibly a TCP RST/FIN) rather than a complete TLS session. That is enough to compute **JA3**. A full **JA3S** fingerprint needs a Server Hello from a TLS-capable listener (for example `openssl s_server`).

## 3. Compute fingerprints

From the repo directory, pointing at your capture file:

```bash
python3 ja3.py handshake.pcap
python3 ja3s.py handshake.pcap
```

Useful flags:

| Flag | Scripts | Meaning |
|------|---------|---------|
| `-a` / `--any_port` | both | Scan all TCP ports, not only 443 |
| `-j` / `--json` | both | JSON output |
| `-r` / `--research` | `ja3.py` only | Keep raw Client Hello bytes in JSON |

Examples:

```bash
python3 ja3.py -j handshake.pcap
python3 ja3.py -a handshake.pcap
python3 ja3s.py -j handshake.pcap
```

JA3 is `MD5(TLSVersion,Ciphers,Extensions,EllipticCurves,EllipticCurvePointFormats)` from the Client Hello (GREASE values stripped). JA3S is `MD5(TLSVersion,Cipher,Extensions)` from the Server Hello.

## 4. Tear down

```bash
sudo ./file_del.sh
```

This deletes namespaces `red`, `blue`, `r1`, and `r2`. Run it before creating the lab again if a previous run left namespaces behind.

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| `Cannot open network namespace` | Run `name_s.sh` with `sudo`. |
| Ping from red to blue fails | Confirm `name_s.sh` finished; `ip netns exec r1 sysctl net.ipv4.ip_forward` is `1`. |
| `ja3.py` prints nothing | File is not a PCAP; handshake is not on port 443 (use `-a`); capture missed Client Hello. |
| Wireshark shows no `ethred` | Launch it with `ip netns exec red wireshark` so it sees namespace interfaces. |
| Namespaces already exist | `sudo ./file_del.sh` then recreate. |

## License

Lab scripts in this repository are provided as-is for education and research.

`ja3.py` and `ja3s.py` retain their original Salesforce copyright and BSD 3-Clause license notices in the file headers.
