# Network Asset Visibility & Inventory

Fast TCP network inventory for authorized networks. The tool uses Masscan for port discovery, optionally enriches results with Nmap, collects TLS certificate data, and produces JSON, CSV, HTML, and change reports.

> Scan only networks and systems you own or are explicitly authorized to assess. Active scans can trigger security alerts and affect fragile devices.

## How It Works

```text
CIDR or detected local network
          |
          v
Masscan: open TCP ports
          |
          v
Nmap: service/version/TLS enrichment (optional)
          |
          v
JSON, CSV, HTML, certificates, change report
```

## Requirements

Supported platforms:

- macOS with Homebrew.
- Debian/Ubuntu and derivatives.
- Fedora/RHEL-based systems.
- Arch-based systems.
- Alpine Linux.

Windows is not supported.

Required commands:

- Bash
- Masscan
- Nmap
- Python 3
- OpenSSL

The scanner can install missing packages on supported systems. Use `--no-install` in controlled production environments.

## Installation

```bash
git clone <repository-url>
cd AiO-Network-Inventory
chmod +x discover.sh
```

Install dependencies manually when preferred:

```bash
# macOS
brew install masscan nmap python openssl

# Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y masscan nmap python3 openssl

# Fedora/RHEL/Rocky/Alma
sudo dnf install -y masscan nmap python3 openssl
```

Verify the installation:

```bash
./discover.sh --version
./discover.sh --help
```

## Permissions

Run as root because Masscan requires raw packet privileges:

```bash
sudo ./discover.sh --quick --no-install
```

For cron or systemd, run the job as root or configure narrowly scoped passwordless sudo. Never store passwords in scripts, environment files, or Git.

## Usage

### Fast recurring inventory

Masscan only. Records hosts and open TCP ports without the slower Nmap phase:

```bash
sudo ./discover.sh \
  --discovery-only \
  --no-install \
  --output /var/lib/network-discovery
```

Use this mode for frequent change detection and larger networks.

### Quick enriched scan

Masscan discovery followed by targeted Nmap service, version, and TLS detection. OS fingerprinting is skipped:

```bash
sudo ./discover.sh \
  --quick \
  --no-install \
  --output /var/lib/network-discovery
```

### Full enriched scan

Same Masscan discovery and Nmap enrichment, with OS fingerprinting enabled:

```bash
sudo ./discover.sh \
  --no-install \
  --output /var/lib/network-discovery
```

### Explicit network

By default, the tool scans the network attached to the default route. Scan another network explicitly:

```bash
sudo ./discover.sh \
  --network 192.168.1.0/24 \
  --quick \
  --no-install
```

### Options

| Option | Purpose |
| --- | --- |
| `--network CIDR` | Scan an explicit IPv4 or IPv6 network. |
| `--output DIR` | Output directory. Default: `./network-discovery`. |
| `--quick` | Targeted enrichment without OS fingerprinting. |
| `--discovery-only` | Masscan-only inventory; implies `--quick`. |
| `--no-install` | Do not install dependencies automatically. |
| `--version` | Print version. |
| `--help` | Print help. |

## Configuration

Configure scan performance through environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `MASSCAN_PORTS` | `1-65535` | TCP port range. |
| `MASSCAN_RATE` | `100000` | Masscan packets per second. |
| `MASSCAN_RETRY_RATE` | `25000` | Rate for an empty-result retry. |
| `MASSCAN_RETRIES` | `1` | Empty-result retries. Set to `0` to disable. |
| `NMAP_HOST_TIMEOUT` | `10m` | Nmap timeout per host. |
| `NMAP_MAX_RETRIES` | `2` | Nmap packet retries. |

Example for Wi-Fi, VPN, or sensitive networks:

```bash
sudo env MASSCAN_RATE=10000 MASSCAN_RETRY_RATE=5000 \
  ./discover.sh --discovery-only --no-install
```

To scan only common service ports:

```bash
sudo env MASSCAN_PORTS=22,53,80,443,8080,8443 \
  ./discover.sh --quick --no-install
```

Masscan already uses an asynchronous high-concurrency engine; shell-level threading is not required. Reduce the rate if packet loss, device impact, or IDS alerts appear.

## Output

Each completed run is stored in a timestamped directory:

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

| File | Contents |
| --- | --- |
| `hosts.txt` | Hosts with open TCP ports. |
| `masscan.txt` | Raw Masscan output. |
| `nmap.xml`, `nmap.txt` | Raw Nmap output. |
| `inventory.json` | Primary machine-readable inventory. |
| `inventory.csv` | Flat host/port export. |
| `inventory.html` | Browser-readable report. |
| `certificates.txt` | TLS certificate summary. |
| `changes.txt` | New/removed hosts and ports. |
| `metadata.json` | Run settings and host count. |

Open the latest report:

```bash
open /var/lib/network-discovery/latest/inventory.html      # macOS
xdg-open /var/lib/network-discovery/latest/inventory.html  # Linux
```

Generated scan data is ignored by Git. Reports can contain IP addresses, hostnames, MAC addresses, software versions, and certificate identities; protect them accordingly.

## TLS and Change Detection

TLS collection checks common TLS ports such as `443`, `465`, `636`, `853`, `993`, `995`, `8443`, and `9443`, plus services identified as SSL/HTTPS by Nmap.

Certificates are classified as:

- `OK`: more than 30 days remaining.
- `WARNING`: 8-30 days remaining.
- `CRITICAL`: 0-7 days remaining.
- `EXPIRED`: past expiration.
- `UNKNOWN`: unavailable or not parseable.

After the first run, the current inventory is compared with the previous one. The report includes new and removed hosts and TCP ports. Service-version and certificate-field changes are not currently part of the diff.

If a host disappears between Masscan and Nmap, its Masscan-confirmed port remains in JSON with empty enrichment fields.

## Automation

Use absolute paths and run as root to avoid an interactive sudo prompt.

### Cron

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/homebrew/bin
0 3 * * * /opt/network-inventory/discover.sh --quick --no-install --output /var/lib/network-discovery >> /var/log/network-inventory.log 2>&1
```

Recommended schedule:

| Frequency | Mode | Purpose |
| --- | --- | --- |
| Every 5-15 minutes | `--discovery-only` | Fast host/port changes. |
| Daily | `--quick` | Service, version, and TLS inventory. |
| Weekly | Full mode | OS fingerprinting and deeper review. |

### systemd

Service:

```ini
[Unit]
Description=Network inventory scan

[Service]
Type=oneshot
ExecStart=/opt/network-inventory/discover.sh --quick --no-install --output /var/lib/network-discovery
```

Timer:

```ini
[Unit]
Description=Daily network inventory scan

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

For automation, consume:

- `latest/inventory.json`
- `latest/changes.txt`
- `latest/certificates.txt`
- `latest/metadata.json`

Treat a nonzero exit code as a failed scan. Do not interpret an empty inventory without checking `masscan.txt` and `nmap.txt`.

## Reliability and Troubleshooting

The scanner:

- Allows only one run per output directory.
- Recovers stale locks after dead processes.
- Retries Masscan once when no open TCP record is reported.
- Uses Nmap host timeouts and retry limits.
- Writes inventory/report artifacts atomically where applicable.
- Preserves Masscan ports when Nmap enrichment is temporarily unavailable.

Useful checks:

```bash
command -v masscan nmap python3 openssl
masscan --version
ps aux | grep -E '[m]asscan|[n]map|[d]iscover.sh'
```

If the scan is too slow:

```bash
sudo env MASSCAN_RATE=10000 \
  NMAP_HOST_TIMEOUT=5m \
  ./discover.sh --quick --no-install
```

If Masscan finds ports but Nmap reports zero hosts, inspect:

```bash
cat network-discovery/latest/masscan.txt
cat network-discovery/latest/nmap.txt
```

Masscan discovery is TCP-only. UDP discovery, authenticated host inspection, application security testing, and service ownership are outside the current scope.

## Development Checks

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
| `discover.sh` | CLI and orchestration. |
| `lib/common.sh` | Logging, locking, directories, validation, metadata. |
| `lib/os.sh` | OS, package-manager, and privilege detection. |
| `lib/packages.sh` | Dependency checks and installation. |
| `lib/network.sh` | Local route and CIDR detection. |
| `lib/scanner.sh` | Masscan discovery and Nmap enrichment. |
| `lib/certificates.sh` | TLS inspection and certificate summaries. |
| `lib/inventory.sh` | Inventory and report generation. |
| `lib/diff.sh` | Previous/current comparison. |

## Roadmap for Platform Engineering

Natural next additions for production use:

- Authenticated SSH collector for OS, disk, memory, packages, systemd, and Docker.
- Docker/Compose, reverse proxy, database, BIND, WireGuard, and GitLab Runner collectors.
- Certificate expiry alerts and Prometheus metrics.
- Ownership metadata and policy checks for unexpected ports or weak TLS.
- Ansible inventory export.
- Backup freshness and restore-test evidence.
- ShellCheck, fixture-based parser tests, and GitLab CI.
- Vault/SOPS/age integration without storing secrets in scan output.

These should be separate authenticated collectors, not more probes in the unauthenticated network scan.
