# Network Discovery & Infrastructure Inventory

Cross-platform network discovery and infrastructure inventory tool designed for automated infrastructure visibility.

The project discovers hosts, open TCP ports, running services, software versions, operating systems and TLS certificates. Results are stored as structured inventory and can be compared against previous scans to identify infrastructure changes.

The tool is designed as a foundation for further automation such as **certificate lifecycle management, ACME/Let's Encrypt integration, Ansible automation, monitoring and CI/CD pipelines**.

---

## Features

* Cross-platform support
* Automatic operating system detection
* Automatic package-manager detection
* Automatic dependency installation
* Automatic local network detection
* Live host discovery
* Full TCP port scanning
* Quick scanning mode
* Service detection
* Software version detection
* OS fingerprinting
* TLS certificate discovery
* Certificate expiration detection
* JSON inventory
* CSV inventory
* HTML report
* Raw Nmap XML output
* Infrastructure change detection
* Timestamped scan history
* `latest` / `previous` scan references
* Designed for unattended execution

---

# Supported Platforms

| Platform     | Package Manager | Status    |
| ------------ | --------------- | --------- |
| Debian       | apt             | Supported |
| Ubuntu       | apt             | Supported |
| Linux Mint   | apt             | Supported |
| Fedora       | dnf             | Supported |
| RHEL         | dnf/yum         | Supported |
| Rocky Linux  | dnf             | Supported |
| AlmaLinux    | dnf             | Supported |
| Arch Linux   | pacman          | Supported |
| Manjaro      | pacman          | Supported |
| Alpine Linux | apk             | Supported |
| macOS        | Homebrew        | Supported |

Windows is currently not supported.

---

# Architecture

```text
                           Network
                              │
                              ▼
                   ┌────────────────────┐
                   │  Network Discovery │
                   │                    │
                   │    discover.sh     │
                   └─────────┬──────────┘
                             │
                    OS / Platform Detection
                             │
             ┌───────────────┼───────────────┐
             │               │               │
             ▼               ▼               ▼
          Linux           macOS         Package Manager
             │               │               │
             └───────────────┴───────────────┘
                             │
                             ▼
                       Dependency Check
                             │
                             ▼
                       Network Detection
                             │
                             ▼
                        Nmap Discovery
                             │
                             ▼
                       Live Host List
                             │
                             ▼
                     Port / Service Scan
                             │
                  ┌──────────┴──────────┐
                  │                     │
                  ▼                     ▼
             OS Detection          TLS Detection
                  │                     │
                  └──────────┬──────────┘
                             ▼
                       Inventory JSON
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
             CSV            HTML          JSON
              │
              ▼
       Previous Inventory
              │
              ▼
        Change Detection
```

---

# Requirements

The script requires:

* Bash
* Nmap
* Python 3
* OpenSSL

The script automatically installs missing dependencies where supported.

### Linux

Supported package managers:

```text
apt
dnf
yum
pacman
apk
```

### macOS

Homebrew is supported.

The script intentionally does **not** install Homebrew automatically because doing so modifies the system beyond the scope of the discovery tool.

Install Homebrew separately if required.

---

# Installation

Clone the repository:

```bash
git clone https://github.com/<user>/<repository>.git
cd <repository>
```

Make the main script executable:

```bash
chmod +x discover.sh
```

Run the discovery:

```bash
sudo ./discover.sh
```

The script automatically detects the operating system and installs required packages when possible.

---

# Basic Usage

## Automatic network detection

```bash
sudo ./discover.sh
```

The tool determines the network associated with the default route.

Example:

```text
[+] OS              : debian
[+] Package manager : apt
[+] Interface       : ens18
[+] Local IP        : 10.20.0.15
[+] Network         : 10.20.0.0/24
```

---

# Explicit Network

A network can be supplied manually:

```bash
sudo ./discover.sh --network 10.20.0.0/24
```

This is useful when:

* scanning a different VLAN
* scanning through a routed interface
* running from a jump host
* testing the tool in a lab environment

---

# Quick Scan

The default mode scans all TCP ports.

For faster discovery, use:

```bash
sudo ./discover.sh --quick
```

Quick mode scans Nmap's top 1000 TCP ports.

For unattended production runs, Nmap uses a default ten-minute host timeout and
two retries. These can be adjusted with environment variables:

```bash
NMAP_HOST_TIMEOUT=15m NMAP_MAX_RETRIES=3 ./discover.sh --quick
```

Runs are serialized per output directory. A second run exits instead of
mixing its results with an active scan.

### Full mode

```text
1-65535 TCP
```

### Quick mode

```text
Top 1000 TCP ports
```

Full mode provides better visibility but can take significantly longer.

---

# Disable Automatic Installation

To prevent the script from modifying the system:

```bash
sudo ./discover.sh --no-install
```

If required dependencies are missing, the script exits with an error describing what must be installed.

This mode is useful for:

* CI/CD
* immutable infrastructure
* controlled production environments
* containers
* systems where package installation is managed externally

---

# Network Discovery

The first stage performs host discovery:

```bash
nmap -sn <network>
```

Example:

```text
10.20.0.1
10.20.0.5
10.20.0.12
10.20.0.20
```

The addresses are stored in:

```text
hosts.txt
```

---

# Service Discovery

Each discovered host is scanned for TCP services.

The full scan performs:

```text
TCP port discovery
        +
service detection
        +
version detection
        +
OS detection
        +
TLS certificate detection
```

Example result:

```text
10.20.0.12

22/tcp    ssh       OpenSSH
80/tcp    http      nginx
443/tcp   https     nginx
5432/tcp  postgres  PostgreSQL
```

---

# TLS Certificate Discovery

TLS-enabled services are inspected using both Nmap and Python's TLS support.

The tool attempts to identify:

* certificate subject
* certificate issuer
* serial number
* validity period
* expiration date
* SAN entries
* days remaining
* certificate status

Certificate status is classified as:

```text
OK
WARNING
CRITICAL
EXPIRED
UNKNOWN
```

The default thresholds are:

| Status   | Condition                          |
| -------- | ---------------------------------- |
| OK       | > 30 days                          |
| WARNING  | 8–30 days                          |
| CRITICAL | 0–7 days                           |
| EXPIRED  | < 0 days                           |
| UNKNOWN  | Expiration could not be determined |

---

# Inventory

The primary machine-readable inventory is:

```text
inventory.json
```

Example:

```json
{
  "generated_at": "2026-09-22T11:30:00+00:00",
  "host_count": 1,
  "hosts": [
    {
      "ip": "10.20.0.12",
      "hostname": "gitlab",
      "mac": "AA:BB:CC:DD:EE:FF",
      "os": "Linux",
      "ports": [
        {
          "port": 22,
          "protocol": "tcp",
          "service": "ssh",
          "product": "OpenSSH",
          "version": "9.2"
        },
        {
          "port": 443,
          "protocol": "tcp",
          "service": "https",
          "product": "nginx",
          "version": "1.24.0"
        }
      ]
    }
  ]
}
```

This JSON can later be consumed by:

* Ansible
* Python
* GitLab CI/CD
* monitoring
* CMDB systems
* custom dashboards
* certificate automation

---

# Output Structure

Every scan creates a timestamped directory:

```text
network-discovery/
│
├── 20260922_113000/
│   ├── hosts.txt
│   ├── nmap.xml
│   ├── nmap.txt
│   ├── inventory.json
│   ├── inventory.csv
│   ├── inventory.html
│   ├── certificates.txt
│   ├── changes.txt
│   └── metadata.json
│
└── latest -> 20260922_113000
```

The `latest` symlink always points to the most recent scan.

After at least two scans:

```text
previous -> <previous scan>
```

is also available.

---

# HTML Report

The HTML report can be opened in any browser:

```bash
open network-discovery/latest/inventory.html
```

On Linux:

```bash
xdg-open network-discovery/latest/inventory.html
```

The report provides an overview of:

* hosts
* IP addresses
* hostnames
* operating systems
* ports
* services
* versions
* TLS certificates

---

# Change Detection

The tool automatically compares the current scan with the previous scan.

Example:

```text
[NEW HOST] 10.20.0.31 docker01
[NEW PORT] 10.20.0.12 8080/tcp
[REMOVED PORT] 10.20.0.20 9200/tcp
```

This makes it possible to detect infrastructure changes without manually comparing inventories.

Potential future integrations include:

```text
New Host
   │
   ▼
GitLab CI
   │
   ▼
Alert
```

or:

```text
New Port
   │
   ▼
Security Review
```

---

# Why Nmap?

Nmap was selected as the primary discovery engine because the project requires more than simple port scanning.

The required information includes:

```text
Host discovery
Port discovery
Service detection
Version detection
OS fingerprinting
TLS inspection
```

Nmap provides these capabilities and produces structured XML output that can be processed by the inventory layer.

---

# Why Not Masscan?

Masscan is optimized for extremely fast scanning of very large address ranges.

For the intended use case, Nmap provides more useful information per scan:

```text
                Nmap

                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
     Ports    Services     OS
                 │
                 ▼
             Versions
                 │
                 ▼
               TLS
```

For a small or medium enterprise subnet, Nmap is generally sufficient.

For larger environments, Masscan could later be introduced as a fast discovery layer:

```text
                    Network
                       │
                       ▼
                   Masscan
                       │
                Open ports
                       │
                       ▼
                    Nmap
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Services       OS           TLS
          │            │            │
          └────────────┼────────────┘
                       ▼
                   Inventory
```

This architecture is intentionally left as a future optimization.

---

# Project Structure

```text
.
├── discover.sh
│
├── lib/
│   ├── common.sh
│   ├── os.sh
│   ├── packages.sh
│   ├── network.sh
│   ├── scanner.sh
│   ├── certificates.sh
│   ├── inventory.sh
│   └── diff.sh
│
├── README.md
├── LICENSE
└── .gitignore
```

### Module responsibilities

| Module            | Responsibility                         |
| ----------------- | -------------------------------------- |
| `discover.sh`     | Main orchestration                     |
| `common.sh`       | Logging, directories, common functions |
| `os.sh`           | OS and package-manager detection       |
| `packages.sh`     | Dependency installation                |
| `network.sh`      | Network/interface detection            |
| `scanner.sh`      | Nmap execution                         |
| `certificates.sh` | TLS inspection                         |
| `inventory.sh`    | JSON/CSV/HTML generation               |
| `diff.sh`         | Previous/current comparison            |

This separation keeps platform-specific functionality isolated and makes the project easier to extend.

---

# Automation

The tool is designed to run unattended.

For example, a daily scan could be scheduled using cron:

```cron
0 3 * * * /opt/network-discovery/discover.sh
```

Or through a systemd timer.

It can also be executed from:

* GitLab CI/CD
* Jenkins
* Ansible
* scheduled jobs
* monitoring systems

---

# CI/CD Integration

A future GitLab pipeline can look like:

```text
                 GitLab Schedule
                        │
                        ▼
                Network Discovery
                        │
              ┌─────────┼─────────┐
              ▼         ▼         ▼
           JSON        CSV       HTML
              │         │         │
              └─────────┼─────────┘
                        ▼
                 GitLab Artifacts
                        │
                        ▼
                 Change Detection
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
          No changes          Changes found
                                  │
                                  ▼
                                Alert
```

---

# Future Roadmap

## Certificate Lifecycle Management

Integrate ACME certificate automation using [`go-acme/lego`](https://github.com/go-acme/lego).

Planned workflow:

```text
Network Discovery
       │
       ▼
HTTPS Services
       │
       ▼
Certificate Inventory
       │
       ▼
Expiration Check
       │
       ├── OK
       │
       └── Expiring
              │
              ▼
             lego
              │
              ▼
        ACME Provider
              │
              ▼
        New Certificate
```

---

## Ansible Integration

The generated inventory can become an input to Ansible:

```text
Nmap
 │
 ▼
inventory.json
 │
 ▼
Ansible
 │
 ├── configure host
 ├── install packages
 ├── deploy configuration
 └── deploy certificate
```

---

## Monitoring

Potential monitoring integrations:

* Prometheus
* Grafana
* Uptime Kuma
* Alertmanager
* email
* Slack
* Microsoft Teams

Example:

```text
Certificate
    │
    ▼
30 days
    │
    ▼
WARNING
    │
    ▼
Monitoring
    │
    ▼
Alert
```

---

## Asset Management

The inventory can eventually serve as a lightweight asset discovery layer:

```text
Host
 ├── IP
 ├── Hostname
 ├── MAC
 ├── OS
 ├── Services
 ├── Versions
 └── Certificates
```

This can later be integrated with a CMDB or internal infrastructure database.

---

# Security Considerations

This tool performs active network scanning.

Only scan networks and systems where you have explicit authorization to perform network discovery.

Scanning can:

* generate significant network traffic
* trigger IDS/IPS alerts
* trigger security monitoring
* interact with exposed services
* consume system resources

The default Nmap timing is deliberately conservative:

```text
-T3
```

For production environments, scan frequency, scope and timing should be agreed with the relevant infrastructure and security teams.

---

# Design Principles

The project follows several principles:

### Automation first

The tool should require as little manual configuration as possible.

### Cross-platform

Platform-specific behavior should be isolated instead of assuming Linux commands are available everywhere.

### Machine-readable output

JSON is treated as the primary automation format.

### Human-readable output

HTML and CSV make the inventory accessible to administrators.

### Reproducibility

Each scan is timestamped and preserved.

### Change visibility

Infrastructure changes should be detectable automatically.

### Extensibility

The discovery layer should be usable as a foundation for future automation.

---

# Example End-to-End Architecture

The long-term goal is an automated infrastructure lifecycle:

```text
                         GitLab
                           │
                    Scheduled Pipeline
                           │
                           ▼
                 ┌──────────────────┐
                 │ Network Discovery│
                 │                  │
                 │      Nmap        │
                 └────────┬─────────┘
                          │
                          ▼
                   Asset Inventory
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
        Hosts          Services       Certificates
          │               │               │
          └───────────────┼───────────────┘
                          ▼
                   Change Detection
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
        Infrastructure             Certificate
           changes                  lifecycle
             │                         │
             ▼                         ▼
           Alert                     lego
                                       │
                                       ▼
                                     ACME
                                       │
                                       ▼
                                 New Certificate
                                       │
                                       ▼
                                   Deployment
                                       │
                                       ▼
                                    Service
```

The project therefore provides the **discovery and inventory layer** for a larger infrastructure automation platform.

---

# License

```text
Apache License 2.0
```
