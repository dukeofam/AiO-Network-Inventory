# Network Discovery & Infrastructure Inventory

A Bash-based network discovery and inventory tool for authorized networks. It discovers live TCP services, enriches them with Nmap service and version detection, collects TLS certificate details, and writes JSON, CSV, HTML, raw Masscan, and raw Nmap output.

The scanner is designed for repeatable operational use, including scheduled scans of medium-sized networks.

> **Authorization required:** Only scan networks and systems that you own or are explicitly authorized to assess. Active scanning can create traffic, trigger security alerts, and affect fragile devices.

## What It Does

The scan pipeline is:

```text
Local network or explicit CIDR
        |
        v
Masscan: fast TCP port discovery
        |
        v
Nmap: targeted service/version/TLS enrichment
        |
        v
Python: inventory and report generation
        |
        v
JSON, CSV, HTML, certificates, raw scan data, change report
```

The tool provides:

- Automatic local network detection.
- Explicit CIDR scanning for routed or lab networks.
- Fast TCP discovery with Masscan.
- Targeted Nmap service and version detection.
- Optional full-mode OS fingerprinting.
- TLS certificate collection and expiry classification.
- JSON inventory for automation.
- CSV inventory for spreadsheets and imports.
- HTML report for human review.
- Raw Masscan list output and Nmap XML/text output.
- Timestamped scan history.
- `latest` and `previous` scan links.
- Infrastructure change detection for hosts and ports.
- Run locking to prevent concurrent scans.
- Stale-lock recovery after interrupted processes.
- Bounded Masscan retry behavior and Nmap host timeouts.

## Requirements

Supported operating systems:

- Debian, Ubuntu, Linux Mint, Pop!_OS.
- Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux.
- Arch Linux, Manjaro, EndeavourOS.
- Alpine Linux.
- macOS.

Windows is not currently supported.

Required commands:

- Bash.
- Masscan.
- Nmap.
- Python 3.
- OpenSSL.

Package managers supported by automatic installation:

| Platform | Package manager |
| --- | --- |
| Debian-based Linux | `apt` |
| Fedora/RHEL-based Linux | `dnf` or `yum` |
| Arch-based Linux | `pacman` |
| Alpine Linux | `apk` |
| macOS | Homebrew |

Homebrew itself is not installed automatically. Install it first from [brew.sh](https://brew.sh/).

## Installation

Clone the repository and enter it:

```bash
git clone <repository-url>
cd AiO-Network-Inventory
chmod +x discover.sh
```

Verify the CLI:

```bash
./discover.sh --version
./discover.sh --help
```

The script can install missing supported dependencies automatically. For controlled production systems, install dependencies through your normal system-management process and use `--no-install`.

### macOS

```bash
brew install masscan nmap python openssl
```

### Debian or Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y masscan nmap python3 openssl
```

### Fedora, RHEL, Rocky, or AlmaLinux

```bash
sudo dnf install -y masscan nmap python3 openssl
```

Package availability varies by distribution. If Masscan is not available in the configured repository, install it according to your organization’s approved package process, then rerun with `--no-install`.

## Permissions and Sudo

Run the scanner as root because Masscan requires raw packet privileges and Nmap OS detection also needs elevated privileges in full mode:

```bash
sudo ./discover.sh --quick --no-install
```

When the command is started with `sudo`, the script runs as root and does not need a second sudo prompt.

For unattended jobs, use one of these approaches:

1. Run the cron or systemd job as root.
2. Configure narrowly scoped passwordless sudo for the scanner and its dependencies.
3. Run the scanner from a controlled service account with the required packet privileges.

Do not put a password in a script, cron entry, environment variable, or Git repository.

## Basic Usage

### Scan the automatically detected local network

```bash
sudo ./discover.sh --quick --no-install
```

The script determines the interface and network associated with the default route. Example:

```text
Interface : en0
Local IP  : 192.168.1.39
Network   : 192.168.1.0/24
```

### Scan an explicit network

```bash
sudo ./discover.sh \
  --network 192.168.1.0/24 \
  --quick \
  --no-install
```

Use `--network` when scanning a different VLAN, a routed subnet, a lab range, or a network that is not associated with the default route.

### Choose an output directory

```bash
sudo ./discover.sh \
  --quick \
  --no-install \
  --output /var/lib/network-discovery
```

The output directory must be writable by the account running the scanner. When using `sudo`, a system path such as `/var/lib/network-discovery` is appropriate.

### Full mode

Full mode enables Nmap OS fingerprinting after Masscan discovers open ports:

```bash
sudo ./discover.sh --no-install
```

Full mode does not blindly scan every TCP port with Nmap. Masscan first discovers open ports, and Nmap enriches only those ports. Full mode is still more expensive because OS detection is enabled.

### Quick mode

Quick mode is intended for regular fleet scans:

```bash
sudo ./discover.sh --quick --no-install
```

Quick mode:

- Uses Masscan for TCP discovery.
- Scans all TCP ports by default.
- Uses targeted Nmap service/version/TLS enrichment.
- Skips OS fingerprinting.
- Uses faster Nmap host grouping.

High dynamic ports are included because the default Masscan range is `1-65535`.

## Command-Line Options

| Option | Description |
| --- | --- |
| `--network CIDR` | Scan an explicit IPv4 or IPv6 network. |
| `--output DIR` | Store results under `DIR`. Default: `./network-discovery`. |
| `--quick` | Skip OS fingerprinting and use the fleet-oriented enrichment profile. |
| `--no-install` | Never install packages automatically. Recommended for production. |
| `--version` | Print the scanner version. |
| `--help` | Print command-line help. |

Example:

```bash
sudo ./discover.sh \
  --network 10.20.0.0/16 \
  --quick \
  --no-install \
  --output /var/lib/network-discovery
```

## Environment Configuration

The command-line interface is intentionally small. Scan tuning is configured through environment variables.

| Variable | Default | Purpose |
| --- | --- | --- |
| `MASSCAN_PORTS` | `1-65535` | TCP port range passed to Masscan. |
| `MASSCAN_RATE` | `20000` | Masscan packets per second. |
| `MASSCAN_RETRY_RATE` | `5000` | Rate used for the automatic empty-result retry. |
| `MASSCAN_RETRIES` | `1` | Number of retries when no open TCP record is reported. |
| `NMAP_HOST_TIMEOUT` | `10m` | Maximum Nmap time per host. |
| `NMAP_MAX_RETRIES` | `2` | Nmap packet retry limit. |

### Rate guidance

Masscan uses an asynchronous high-concurrency engine; shell-level threading is not required. Start conservatively and increase the rate only after observing packet loss, device impact, and network monitoring:

```bash
sudo env MASSCAN_RATE=10000 ./discover.sh --quick --no-install
```

The default `20000` packets per second is intended as a moderate starting point for a normal wired LAN. Use a lower value for Wi-Fi, VPN, routed networks, fragile devices, or networks with strict IDS thresholds:

```bash
sudo env MASSCAN_RATE=5000 \
  MASSCAN_RETRY_RATE=2000 \
  ./discover.sh --quick --no-install
```

Use a higher rate only with explicit authorization and measured capacity:

```bash
sudo env MASSCAN_RATE=50000 ./discover.sh --quick --no-install
```

### Limit the port range

A narrower range can reduce traffic substantially, but it will not discover services outside that range:

```bash
sudo env MASSCAN_PORTS=22,53,80,443,8080,8443 \
  ./discover.sh --quick --no-install
```

### Disable the empty-result retry

```bash
sudo env MASSCAN_RETRIES=0 ./discover.sh --quick --no-install
```

The retry exists to handle transient packet loss or a dropped first sweep. It does not guarantee discovery of every filtered or unstable endpoint.

## Output Layout

Each completed run is stored in its own timestamped directory:

```text
network-discovery/
├── 20260922_142300_38952/
│   ├── hosts.txt
│   ├── masscan.txt
│   ├── nmap.xml
│   ├── nmap.txt
│   ├── inventory.json
│   ├── inventory.csv
│   ├── inventory.html
│   ├── certificates.txt
│   ├── changes.txt
│   └── metadata.json
├── latest -> 20260922_142300_38952
└── previous -> <previous-run>
```

Generated scan data is ignored by Git. Do not commit local inventories, MAC addresses, hostnames, certificate details, or raw scan logs unless that is intentional and approved.

### Output files

| File | Purpose |
| --- | --- |
| `hosts.txt` | Hosts with at least one Masscan-confirmed open TCP port. |
| `masscan.txt` | Raw Masscan list output. |
| `nmap.xml` | Raw structured Nmap output. |
| `nmap.txt` | Human-readable Nmap output. |
| `inventory.json` | Primary machine-readable inventory. |
| `inventory.csv` | Flat host/port export. |
| `inventory.html` | Browser-readable report. |
| `certificates.txt` | TLS certificate status summary. |
| `changes.txt` | Difference from the previous completed inventory. |
| `metadata.json` | Run configuration and summary metadata. |

Open the latest HTML report on macOS:

```bash
open /var/lib/network-discovery/latest/inventory.html
```

On Linux:

```bash
xdg-open /var/lib/network-discovery/latest/inventory.html
```

## Inventory Data

A normal `inventory.json` contains hosts and their open ports:

```json
{
  "generated_at": "2026-09-22T14:23:36+00:00",
  "host_count": 1,
  "hosts": [
    {
      "ip": "192.168.1.180",
      "hostname": "pi.hole",
      "mac": "B8:27:EB:2A:63:CF",
      "os": "",
      "ports": [
        {
          "port": 443,
          "protocol": "tcp",
          "service": "ssl/webdav",
          "product": "",
          "version": "",
          "extrainfo": "",
          "certificate": {},
          "certificate_live": {}
        }
      ]
    }
  ]
}
```

In quick mode, `os` is normally empty because OS fingerprinting is disabled. In full mode, Nmap may populate it when the target responds sufficiently for fingerprinting.

A Masscan-confirmed port is retained even if the target becomes unavailable before Nmap enrichment. In that case, the port remains in the inventory with empty service/version fields. This distinguishes “port discovered, enrichment unavailable” from “port not discovered.”

## TLS Certificates

TLS inspection is attempted for:

- Ports commonly associated with TLS: `443`, `465`, `636`, `853`, `993`, `995`, `8443`, and `9443`.
- Services identified by Nmap as SSL or HTTPS.
- Ports where Nmap reported certificate data.

The collector records:

- Subject.
- Issuer.
- Serial number.
- Not-before and not-after timestamps.
- DNS SAN entries.
- Days remaining.
- Collection errors, when applicable.

Certificate status is classified as:

| Status | Condition |
| --- | --- |
| `OK` | More than 30 days remaining. |
| `WARNING` | 8-30 days remaining. |
| `CRITICAL` | 0-7 days remaining. |
| `EXPIRED` | Expiration is in the past. |
| `UNKNOWN` | The certificate could not be read or dated. |

Certificate collection does not validate trust chains. It is intended to inventory what a service presents, including self-signed and privately issued certificates.

## Change Detection

After the first completed run, the scanner compares the current inventory with the previous one. It reports:

- New hosts.
- Removed hosts.
- New TCP ports.
- Removed TCP ports.

Example:

```text
[NEW HOST] 192.168.1.25 workstation
[NEW PORT] 192.168.1.180 8443/tcp
[REMOVED PORT] 192.168.1.1 1900/tcp
```

The comparison currently focuses on host identity and open port/protocol changes. It does not report every service-version or certificate-field change.

`latest` points to the most recently finalized run. `previous` points to the run that was latest immediately before it.

## Automation

### Cron

Use an absolute repository path and an absolute output path. Run as root to avoid interactive sudo prompts:

```cron
0 3 * * * /opt/network-inventory/discover.sh --quick --no-install --output /var/lib/network-discovery >> /var/log/network-inventory.log 2>&1
```

Make sure the cron environment includes `masscan`, `nmap`, `python3`, and `openssl` in `PATH`. A robust cron entry can define it explicitly:

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/homebrew/bin
0 3 * * * /opt/network-inventory/discover.sh --quick --no-install --output /var/lib/network-discovery >> /var/log/network-inventory.log 2>&1
```

### systemd timer

Example service:

```ini
[Unit]
Description=Network inventory scan

[Service]
Type=oneshot
ExecStart=/opt/network-inventory/discover.sh --quick --no-install --output /var/lib/network-discovery
```

Example timer:

```ini
[Unit]
Description=Daily network inventory scan

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Run the service as root or grant the service only the privileges required by Masscan and Nmap.

### CI/CD and monitoring

For automation, consume:

- `latest/inventory.json` for structured inventory.
- `latest/changes.txt` for port and host changes.
- `latest/certificates.txt` for certificate checks.
- `latest/metadata.json` for run status and summary values.

Treat a nonzero exit code as a failed scan. Do not treat an empty inventory as proof that the network is empty without checking `masscan.txt`, `nmap.txt`, and the command log.

## Reliability and Safety Behavior

- Only one scan can use a given output directory at a time.
- A stale lock from a dead process is removed automatically.
- A live concurrent scan causes the second scan to exit.
- Masscan retries once when no open TCP record is reported, unless `MASSCAN_RETRIES=0`.
- Nmap uses a per-host timeout and retry limit.
- Inventory and report files are written atomically where applicable.
- A target that disappears between Masscan and Nmap is retained from Masscan output.
- The scanner does not install Homebrew automatically.
- The scanner does not silently continue when required dependencies are missing with `--no-install`.

## Troubleshooting

### `masscan: command not found`

Install Masscan and verify it is in the execution `PATH`:

```bash
command -v masscan
masscan --version
```

### `Masscan requires root privileges or passwordless sudo`

Run the scanner with `sudo` or configure the service account according to your security policy:

```bash
sudo ./discover.sh --quick --no-install
```

### Masscan reports no open ports

Check:

1. You are scanning the intended CIDR.
2. The interface has a route to that network.
3. The scan is authorized and not blocked by a firewall or IDS.
4. The target devices are online.
5. `masscan.txt` contains an `open tcp` record.
6. The configured rate is appropriate for the network.

Try a lower-rate retry manually through the environment:

```bash
sudo env MASSCAN_RATE=5000 MASSCAN_RETRY_RATE=2000 \
  ./discover.sh --quick --no-install
```

### Nmap reports zero hosts after Masscan finds ports

This can happen when a service closes or filters the port between the two phases. The tool preserves the Masscan-confirmed port in `inventory.json` with empty enrichment fields. Check:

```bash
cat network-discovery/latest/masscan.txt
cat network-discovery/latest/nmap.txt
jq . network-discovery/latest/inventory.json
```

The Nmap command uses `-Pn` because Masscan has already established reachability at the discovery stage.

### The scan is too slow

Try:

```bash
sudo env MASSCAN_RATE=10000 NMAP_HOST_TIMEOUT=5m \
  ./discover.sh --quick --no-install
```

For a controlled service inventory, limit the port range:

```bash
sudo env MASSCAN_PORTS=22,53,80,443,8080,8443 \
  ./discover.sh --quick --no-install
```

Do not increase the rate blindly. Packet loss can reduce accuracy and increase retries.

### A second scan says the output directory is locked

Check for an active process:

```bash
ps aux | grep -E '[m]asscan|[n]map|[d]iscover.sh'
```

If no scan is running, the next invocation should recover a stale lock automatically. Do not delete a lock while a real scan is active.

### Permission denied under `/var/lib/network-discovery`

Create the output directory with appropriate ownership before running as a service:

```bash
sudo mkdir -p /var/lib/network-discovery
sudo chown root:wheel /var/lib/network-discovery
```

Use the correct group for your Linux distribution.

### OS detection is empty

Expected in `--quick` mode. Use full mode:

```bash
sudo ./discover.sh --no-install
```

Even in full mode, OS fingerprinting is probabilistic and can fail against filtered, embedded, or unusual devices.

## Development and Validation

Run the local static checks:

```bash
bash -n discover.sh lib/*.sh
python3 - <<'PY'
import ast
from pathlib import Path

for path in sorted(Path("lib").glob("*.sh")):
    for block in path.read_text().split("<<'PY'")[1:]:
        ast.parse(block.split("\nPY", 1)[0])

print("embedded Python: OK")
PY
```

Do not run an active network scan in automated tests without an explicit test network. Test parsing and report generation with captured or mocked Masscan/Nmap output instead.

## Project Structure

```text
.
├── discover.sh
├── lib/
│   ├── certificates.sh
│   ├── common.sh
│   ├── diff.sh
│   ├── inventory.sh
│   ├── network.sh
│   ├── os.sh
│   ├── packages.sh
│   └── scanner.sh
├── .gitignore
├── LICENSE
└── README.md
```

| File | Responsibility |
| --- | --- |
| `discover.sh` | CLI, orchestration, and scan lifecycle. |
| `lib/common.sh` | Logging, directories, locking, validation, and metadata. |
| `lib/os.sh` | OS, package-manager, and privilege detection. |
| `lib/packages.sh` | Dependency checks and supported installation. |
| `lib/network.sh` | Local interface, route, address, and CIDR detection. |
| `lib/scanner.sh` | Masscan discovery and targeted Nmap enrichment. |
| `lib/certificates.sh` | TLS certificate collection and summary generation. |
| `lib/inventory.sh` | Nmap XML parsing and JSON/CSV/HTML generation. |
| `lib/diff.sh` | Previous/current host and port comparison. |

## Operational Notes

- Network scans can reveal sensitive infrastructure details. Protect output permissions and backups.
- Raw XML, HTML, CSV, and JSON may contain IP addresses, hostnames, MAC addresses, software versions, and certificate identities.
- Nmap service detection is probabilistic; confirm important findings directly on the target.
- Masscan discovers TCP ports. UDP discovery is not currently implemented.
- The tool does not authenticate to services or validate application-level security.
- A successful scan means the pipeline completed, not that every host or service was reachable.
