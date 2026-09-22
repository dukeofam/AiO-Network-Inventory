#!/usr/bin/env bash

parse_nmap_inventory() {

    log "Parsing Nmap XML inventory..."

    python3 - "$NMAP_XML" "$JSON_FILE" "$CSV_FILE" "${1:-}" <<'PY'
import csv
import datetime
import json
import os
import socket
import sys
import xml.etree.ElementTree as ET

xml_file = sys.argv[1]
json_file = sys.argv[2]
csv_file = sys.argv[3]
masscan_file = sys.argv[4]

tree = ET.parse(xml_file)
root = tree.getroot()

hosts = []


def merge_masscan_results():

    if not masscan_file:
        return

    known_hosts = {host["ip"]: host for host in hosts}

    try:
        with open(masscan_file, encoding="utf-8") as f:
            lines = f

            for line in lines:
                fields = line.split()

                if len(fields) < 4 or fields[0:2] != ["open", "tcp"]:
                    continue

                port_number = int(fields[2])
                ip = fields[3]
                host_data = known_hosts.get(ip)

                if host_data is None:
                    host_data = {
                        "ip": ip,
                        "hostname": "",
                        "mac": "",
                        "os": "",
                        "ports": []
                    }
                    hosts.append(host_data)
                    known_hosts[ip] = host_data

                if any(port["port"] == port_number for port in host_data["ports"]):
                    continue

                host_data["ports"].append({
                    "port": port_number,
                    "protocol": "tcp",
                    "service": "",
                    "product": "",
                    "version": "",
                    "extrainfo": "",
                    "certificate": {}
                })

    except OSError:
        pass


def reverse_dns(ip):

    try:
        return socket.gethostbyaddr(ip)[0]
    except Exception:
        return ""


for host in root.findall("host"):

    status = host.find("status")

    if status is None or status.get("state") != "up":
        continue

    address = host.find("./address[@addrtype='ipv4']")

    if address is None:
        address = host.find("./address[@addrtype='ipv6']")

    if address is None:
        continue

    ip = address.get("addr", "")

    mac_element = host.find("./address[@addrtype='mac']")

    mac = ""

    if mac_element is not None:
        mac = mac_element.get("addr", "")

    hostname = ""

    hostname_element = host.find(
        "./hostnames/hostname"
    )

    if hostname_element is not None:
        hostname = hostname_element.get(
            "name",
            ""
        )

    if not hostname:
        hostname = reverse_dns(ip)

    os_name = ""

    os_match = host.find("./os/osmatch")

    if os_match is not None:
        os_name = os_match.get("name", "")

    host_data = {
        "ip": ip,
        "hostname": hostname,
        "mac": mac,
        "os": os_name,
        "ports": []
    }

    for port in host.findall("./ports/port"):

        state = port.find("state")

        if state is None:
            continue

        if state.get("state") != "open":
            continue

        port_id = int(
            port.get("portid", "0")
        )

        protocol = port.get(
            "protocol",
            "tcp"
        )

        service = port.find("service")

        service_name = ""
        product = ""
        version = ""
        extra = ""

        if service is not None:

            service_name = service.get(
                "name",
                ""
            )

            product = service.get(
                "product",
                ""
            )

            version = service.get(
                "version",
                ""
            )

            extra = service.get(
                "extrainfo",
                ""
            )

        certificate = {}

        for script in port.findall("./script"):

            if script.get("id") != "ssl-cert":
                continue

            output = script.get(
                "output",
                ""
            )

            certificate = {
                "nmap_output": output
            }

        host_data["ports"].append({
            "port": port_id,
            "protocol": protocol,
            "service": service_name,
            "product": product,
            "version": version,
            "extrainfo": extra,
            "certificate": certificate
        })

    hosts.append(host_data)


merge_masscan_results()


inventory = {
    "generated_at": datetime.datetime.now(
        datetime.timezone.utc
    ).isoformat(),

    "host_count": len(hosts),

    "hosts": hosts
}


temporary_json = f"{json_file}.tmp.{os.getpid()}"

with open(temporary_json, "w", encoding="utf-8") as f:

    json.dump(
        inventory,
        f,
        indent=2,
        ensure_ascii=False
    )

    f.write("\n")

os.replace(temporary_json, json_file)


temporary_csv = f"{csv_file}.tmp.{os.getpid()}"

with open(
    temporary_csv,
    "w",
    newline="",
    encoding="utf-8"
) as f:

    writer = csv.writer(f)

    writer.writerow([
        "IP",
        "Hostname",
        "MAC",
        "OS",
        "Port",
        "Protocol",
        "Service",
        "Product",
        "Version",
        "ExtraInfo"
    ])

    for host in hosts:

        for port in host["ports"]:

            writer.writerow([
                host["ip"],
                host["hostname"],
                host["mac"],
                host["os"],
                port["port"],
                port["protocol"],
                port["service"],
                port["product"],
                port["version"],
                port["extrainfo"]
            ])

os.replace(temporary_csv, csv_file)
PY
}


generate_reports() {

    log "Generating HTML report..."

    python3 - "$JSON_FILE" "$HTML_FILE" <<'PY'
import html
import json
import os
import sys

json_file = sys.argv[1]
html_file = sys.argv[2]

with open(json_file, encoding="utf-8") as f:
    inventory = json.load(f)


rows = []

for host in inventory.get("hosts", []):

    for port in host.get("ports", []):

        cert = port.get(
            "certificate_live",
            {}
        )

        cert_text = ""

        if cert:

            days = cert.get(
                "days_remaining"
            )

            cert_text = (
                f"<b>Subject:</b> "
                f"{html.escape(cert.get('subject',''))}<br>"
                f"<b>Issuer:</b> "
                f"{html.escape(cert.get('issuer',''))}<br>"
                f"<b>Expires:</b> "
                f"{html.escape(cert.get('not_after',''))}<br>"
                f"<b>Days:</b> "
                f"{html.escape(str(days))}"
            )

        rows.append(
            "<tr>"
            f"<td>{html.escape(host.get('ip',''))}</td>"
            f"<td>{html.escape(host.get('hostname',''))}</td>"
            f"<td>{html.escape(host.get('os',''))}</td>"
            f"<td>{port.get('port','')}/{html.escape(port.get('protocol',''))}</td>"
            f"<td>{html.escape(port.get('service',''))}</td>"
            f"<td>{html.escape(port.get('product',''))}</td>"
            f"<td>{html.escape(port.get('version',''))}</td>"
            f"<td>{cert_text}</td>"
            "</tr>"
        )


document = f"""<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<title>Network Discovery</title>

<style>

body {{
    font-family: Arial, sans-serif;
    margin: 40px;
    background: #f5f5f5;
}}

h1 {{
    margin-bottom: 5px;
}}

.summary {{
    margin-bottom: 25px;
}}

table {{
    border-collapse: collapse;
    width: 100%;
    background: white;
}}

th {{
    background: #222;
    color: white;
    padding: 10px;
    text-align: left;
}}

td {{
    padding: 8px;
    border-bottom: 1px solid #ddd;
    vertical-align: top;
}}

tr:hover {{
    background: #f0f0f0;
}}

</style>

</head>

<body>

<h1>Network Discovery</h1>

<div class="summary">

<b>Generated:</b>
{html.escape(inventory.get('generated_at',''))}

<br>

<b>Hosts:</b>
{inventory.get('host_count', 0)}

</div>

<table>

<thead>

<tr>
<th>IP</th>
<th>Hostname</th>
<th>OS</th>
<th>Port</th>
<th>Service</th>
<th>Product</th>
<th>Version</th>
<th>TLS Certificate</th>
</tr>

</thead>

<tbody>

{''.join(rows)}

</tbody>

</table>

</body>

</html>
"""


temporary_html = f"{html_file}.tmp.{os.getpid()}"

with open(
    temporary_html,
    "w",
    encoding="utf-8"
) as f:

    f.write(document)

os.replace(temporary_html, html_file)
PY
}