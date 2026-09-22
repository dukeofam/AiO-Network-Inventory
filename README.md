# Network Discovery & Infrastructure Inventory

Automated network discovery and infrastructure inventory tool for Linux environments.

The project uses **Nmap** to discover hosts, open ports, running services, software versions, operating systems and TLS certificates. Results are exported into machine-readable and human-readable formats and can be compared with previous scans to detect infrastructure changes.

The project is designed as a lightweight foundation for **infrastructure discovery, asset inventory, security visibility and certificate lifecycle automation**.

---

## Features

* Automatic local network detection
* Automatic dependency installation on Debian-based systems
* Live host discovery
* Full TCP port discovery
* Service and version detection
* OS fingerprinting
* TLS certificate discovery
* Certificate expiration information
* JSON inventory
* CSV inventory
* HTML report
* Nmap XML output
* Human-readable Nmap report
* Infrastructure change detection
* Detection of:

  * new hosts
  * removed hosts
  * newly opened ports
  * closed/removed ports
* Timestamped scan results
* `latest` symlink for easy integration with automation
* Designed to run unattended

---

## Architecture

```text
                         Network
                            │
                            ▼
                  ┌───────────────────┐
                  │  Network Discovery│
                  │                   │
                  │     discover.sh   │
                  └─────────┬─────────┘
                            │
                            ▼
                       Nmap Host Scan
                            │
                            ▼
                     Live Host List
                            │
                            ▼
                    Full TCP Port Scan
                            │
                            ▼
                  Service / Version Scan
                            │
                  ┌─────────┴─────────┐
                  │                   │
                  ▼                   ▼
              OS Detection       TLS Detection
                  │                   │
                  └─────────┬─────────┘
                            │
                            ▼
                    Structured Inventory
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
           JSON             CSV           HTML
             │
             ▼
       Previous Scan
             │
             ▼
       Change Detection
             │
             ├── New host
             ├── Removed host
             ├── New port
             └── Removed port
```

---

## Requirements

The script is intended primarily for:

* Debian 12/13
* Ubuntu
* other Debian-based Linux distributions

Required tools:

* `nmap`
* `python3`
* `iproute2`
* `openssl`

The script automatically installs missing packages using `apt`.

### Permissions

Some Nmap functionality, especially OS detection and certain discovery methods, requires elevated privileges.

Run the script with:

```bash
sudo ./discover.sh
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/<your-user>/<your-repository>.git
cd <your-repository>
```

Make the script executable:

```bash
chmod +x discover.sh
```

Run:

```bash
sudo ./discover.sh
```

No additional configuration is required for the basic use case.

---

# How It Works

## 1. Network Detection

The script determines the network interface and source IP used to reach the default route.

For example:

```text
Interface : ens18
Local IP  : 10.20.0.15
Network   : 10.20.0.0/24
```

The detected CIDR is then used as the discovery target.

---

## 2. Host Discovery

Nmap first performs host discovery:

```bash
nmap -sn 10.20.0.0/24
```

This identifies hosts that appear to be online without performing the full service scan.

The resulting addresses are stored in:

```text
hosts.txt
```

Example:

```text
10.20.0.1
10.20.0.5
10.20.0.12
10.20.0.20
```

---

## 3. Port Discovery

The discovered hosts are then scanned for all TCP ports:

```text
1-65535
```

The scan also performs:

* service detection
* version detection
* OS detection where possible
* TLS certificate detection

The main Nmap scan is approximately equivalent to:

```bash
nmap \
    -p- \
    -sV \
    -O \
    --open \
    --script ssl-cert
```

The exact arguments are handled automatically by `discover.sh`.

---

## 4. Service Detection

For every discovered open port, Nmap attempts to identify the service.

Example:

```text
22/tcp    ssh      OpenSSH 9.2
80/tcp    http     nginx 1.24.0
443/tcp   https    nginx 1.24.0
5432/tcp  postgres PostgreSQL
```

Where available, additional information such as product and version is stored.

---

## 5. OS Detection

Nmap attempts to fingerprint the operating system.

Example:

```json
{
  "ip": "10.20.0.12",
  "os": "Linux"
}
```

OS detection is inherently probabilistic and may not always produce a result.

---

# TLS Certificate Discovery

The scan uses Nmap's `ssl-cert` NSE script to inspect TLS-enabled services.

For example:

```text
443/tcp
8443/tcp
9443/tcp
```

The inventory can contain:

* certificate subject
* certificate issuer
* validity start
* validity end
* SAN information where available

Example:

```json
"certificate": {
  "subject": "CN=git.example.com",
  "issuer": "Let's Encrypt",
  "valid_from": "...",
  "valid_to": "..."
}
```

This provides the foundation for future certificate lifecycle automation.

---

# Output

Every execution creates a timestamped directory.

Example:

```text
network-discovery/
├── 20260922_113000/
│   ├── hosts.txt
│   ├── nmap.xml
│   ├── nmap.txt
│   ├── inventory.json
│   ├── inventory.csv
│   ├── inventory.html
│   ├── certificates.txt
│   └── changes.txt
│
└── latest -> 20260922_113000
```

---

## JSON Inventory

`inventory.json` is intended for automation and integration with other systems.

Example:

```json
{
  "generated_at": "2026-09-22T11:30:00+00:00",
  "host_count": 2,
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
          "version": "9.2",
          "certificate": {}
        },
        {
          "port": 443,
          "protocol": "tcp",
          "service": "https",
          "product": "nginx",
          "version": "1.24.0",
          "certificate": {
            "subject": "CN=git.example.com",
            "issuer": "Let's Encrypt",
            "valid_to": "..."
          }
        }
      ]
    }
  ]
}
```

The JSON output can later be consumed by:

* Ansible
* Python automation
* monitoring systems
* CMDB systems
* GitLab CI/CD
* certificate management workflows
* custom dashboards

---

# CSV Inventory

`inventory.csv` provides a flat representation suitable for spreadsheets and simple data processing.

Example:

```text
IP,Hostname,OS,Port,Protocol,Service,Product,Version
10.20.0.12,gitlab,Linux,22,tcp,ssh,OpenSSH,9.2
10.20.0.12,gitlab,Linux,443,tcp,https,nginx,1.24.0
```

---

# HTML Report

`inventory.html` provides a simple human-readable overview.

Open it locally:

```bash
xdg-open network-discovery/latest/inventory.html
```

or copy it to a web server / artifact repository.

The report contains:

* IP address
* hostname
* operating system
* open ports
* services
* product
* version
* TLS certificate information

---

# Change Detection

Every scan is compared with the previous scan.

The script detects:

### New hosts

```text
[NEW HOST] 10.20.0.31 docker01
```

### Removed hosts

```text
[REMOVED HOST] 10.20.0.31 docker01
```

### Newly opened ports

```text
[NEW PORT] 10.20.0.12 8080/tcp
```

### Removed ports

```text
[REMOVED PORT] 10.20.0.20 9200/tcp
```

The result is stored in:

```text
changes.txt
```

This makes the discovery tool suitable for scheduled execution.

---

# Configuration

The default output directory is:

```text
./network-discovery
```

It can be changed using the `DISCOVERY_DIR` environment variable.

Example:

```bash
sudo DISCOVERY_DIR=/var/lib/network-discovery ./discover.sh
```

---

# Automation

The script is designed to be suitable for scheduled execution.

For example, a daily cron job could run:

```bash
0 3 * * * /opt/network-discovery/discover.sh
```

Or it can be executed by:

* GitLab CI/CD
* Jenkins
* Ansible
* systemd timers
* cron
* other automation platforms

A scheduled scan can therefore provide continuous visibility into infrastructure changes.

---

# Example Workflow

A simple operational workflow could look like:

```text
                   Scheduled Scan
                         │
                         ▼
                    discover.sh
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       Current Inventory       Previous Inventory
             │                       │
             └───────────┬───────────┘
                         ▼
                  Change Detection
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
          New Host    New Port    TLS Change
             │           │           │
             └───────────┴───────────┘
                         ▼
                       Alert
```

---

# Security Considerations

Network scanning should only be performed on networks and systems where you have explicit authorization to perform scanning.

The script performs active network discovery and service enumeration. Depending on the environment, scanning can:

* generate network traffic
* trigger IDS/IPS alerts
* trigger security monitoring
* interact with exposed services
* consume network or host resources

The default scan uses Nmap timing `-T3` to provide a relatively conservative scanning profile.

For production environments, scanning frequency and timing should be adapted to the organization's security and operational requirements.

---

# Why Nmap?

Nmap was selected as the primary discovery engine because the project needs more than simple port scanning.

The inventory requires:

```text
Host discovery
     +
Port discovery
     +
Service detection
     +
Version detection
     +
OS detection
     +
TLS certificate discovery
```

Nmap provides these capabilities within one mature tool and produces XML output that can be reliably consumed by automation.

---

# Why Not Masscan?

`masscan` is extremely useful for high-speed scanning of large address ranges.

However, this project prioritizes:

* service identification
* version information
* OS fingerprinting
* TLS information
* structured output

For a typical enterprise subnet such as:

```text
10.20.0.0/24
```

Nmap is sufficient and keeps the architecture simple.

For significantly larger environments, a future architecture could use:

```text
                  masscan
                     │
             Fast port discovery
                     │
                     ▼
                  Nmap
                     │
              Deep inspection
                     │
                     ▼
               Inventory
```

Masscan can therefore be introduced later as an optimization rather than as a requirement.

---

# Roadmap

The current implementation provides the basic discovery and inventory layer.

Planned improvements include:

## Certificate Management

Integrate ACME certificate management using [`lego`](https://github.com/go-acme/lego).

Potential workflow:

```text
Discovery
    │
    ▼
HTTPS Service
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

## GitLab CI/CD

Automate scans using scheduled GitLab pipelines.

Possible pipeline:

```text
GitLab Schedule
      │
      ▼
Network Discovery
      │
      ├── inventory.json
      ├── inventory.csv
      ├── inventory.html
      └── changes.txt
                │
                ▼
          GitLab Artifacts
```

## Monitoring

Integrate certificate expiration with monitoring and alerting.

Potential integrations:

* Uptime Kuma
* Prometheus
* Grafana
* Alertmanager
* email
* Slack / Teams

## Ansible Integration

Use the generated JSON inventory as an input to Ansible automation.

For example:

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
 ├── deploy certificate
 └── restart service
```

## Asset Change Alerts

Future versions can generate alerts when:

* a new server appears
* an unexpected port opens
* a service version changes
* a server disappears
* a TLS certificate changes
* a certificate approaches expiration

---

# Project Structure

```text
.
├── discover.sh
├── README.md
└── network-discovery/
    └── <timestamped scan results>
```

Generated scan results should generally not be committed to the repository.

Recommended `.gitignore`:

```gitignore
network-discovery/
*.log
```

---

# Use Case

This project can serve as a foundation for an internal infrastructure discovery and certificate-management platform.

A possible end-to-end architecture is:

```text
                    ┌───────────────┐
                    │    GitLab     │
                    │    CI/CD      │
                    └───────┬───────┘
                            │
                       Scheduled Job
                            │
                            ▼
                  ┌───────────────────┐
                  │ Network Discovery │
                  │                   │
                  │      Nmap         │
                  └─────────┬─────────┘
                            │
                            ▼
                    Infrastructure
                       Inventory
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
       Servers           Services        Certificates
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ▼
                     Change Detection
                            │
                            ▼
                        Alerting
                            │
                            ▼
                    Certificate Lifecycle
                            │
                            ▼
                           ACME
                            │
                            ▼
                          lego
```

The goal is to move infrastructure management from **manual discovery and manual certificate handling** toward a reproducible and automated workflow.

---

# License

```text
Apache License 2.0
```

See the selected license file for the full terms.
