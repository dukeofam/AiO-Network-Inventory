#!/usr/bin/env bash

scan_certificate_details() {

    log "Collecting TLS certificate information..."

    : > "$CERTIFICATES_FILE"

    python3 - "$JSON_FILE" "$CERTIFICATES_FILE" <<'PY'
import json
import os
import socket
import ssl
import sys
import tempfile
from datetime import datetime, timezone

json_file = sys.argv[1]
output_file = sys.argv[2]

with open(json_file, encoding="utf-8") as f:
    inventory = json.load(f)

certificate_lines = []


def get_certificate(host, port, server_name):

    result = {
        "subject": "",
        "issuer": "",
        "serial": "",
        "not_before": "",
        "not_after": "",
        "san": [],
        "days_remaining": None,
        "error": ""
    }

    context = ssl.create_default_context()

    # Certificate inspection does not need successful validation.
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    try:

        with socket.create_connection(
            (host, port),
            timeout=5
        ) as sock:

            with context.wrap_socket(
                sock,
                server_hostname=server_name
            ) as tls:

                der_certificate = tls.getpeercert(binary_form=True)

                if not der_certificate:
                    result["error"] = "No certificate returned."
                    return result

                certificate_path = None

                try:
                    with tempfile.NamedTemporaryFile(
                        mode="wb",
                        suffix=".der",
                        delete=False
                    ) as certificate_file:
                        certificate_file.write(der_certificate)
                        certificate_path = certificate_file.name

                    # Decode the certificate without requiring a trusted CA.
                    cert = ssl._ssl._test_decode_cert(certificate_path)
                finally:
                    if certificate_path:
                        os.unlink(certificate_path)

                subject = cert.get("subject", ())
                issuer = cert.get("issuer", ())

                def flatten(value):
                    values = []

                    for item in value:
                        for key, val in item:
                            values.append(f"{key}={val}")

                    return ", ".join(values)

                result["subject"] = flatten(subject)
                result["issuer"] = flatten(issuer)
                result["serial"] = cert.get("serialNumber", "")
                result["not_before"] = cert.get("notBefore", "")
                result["not_after"] = cert.get("notAfter", "")

                result["san"] = [
                    value
                    for key, value in cert.get(
                        "subjectAltName",
                        []
                    )
                    if key == "DNS"
                ]

                if result["not_after"]:

                    expiry = datetime.strptime(
                        result["not_after"],
                        "%b %d %H:%M:%S %Y %Z"
                    ).replace(tzinfo=timezone.utc)

                    result["days_remaining"] = (
                        expiry - datetime.now(timezone.utc)
                    ).days

    except Exception as exc:

        result["error"] = str(exc)

    return result


for host in inventory.get("hosts", []):

    ip = host.get("ip", "")
    hostname = host.get("hostname", "")

    for port_data in host.get("ports", []):

        port = int(port_data.get("port", 0))

        # Only inspect likely TLS ports/services.
        service = (
            port_data.get("service", "")
            .lower()
        )

        if not (
            port in {
                443,
                465,
                636,
                853,
                993,
                995,
                8443,
                9443
            }
            or "ssl" in service
            or "https" in service
            or port_data.get("certificate")
        ):
            continue

        cert = get_certificate(ip, port, hostname or ip)

        port_data["certificate_live"] = cert

        status = "UNKNOWN"

        days = cert.get("days_remaining")

        if isinstance(days, int):

            if days < 0:
                status = "EXPIRED"
            elif days <= 7:
                status = "CRITICAL"
            elif days <= 30:
                status = "WARNING"
            else:
                status = "OK"

        certificate_lines.append(
            f"{ip}:{port} "
            f"hostname={hostname} "
            f"status={status} "
            f"days={days} "
            f"subject={cert.get('subject','')} "
            f"issuer={cert.get('issuer','')}"
        )

with open(output_file, "w", encoding="utf-8") as f:
    if certificate_lines:
        f.write("\n".join(certificate_lines) + "\n")

# Replace the inventory only after the complete certificate pass succeeds.
temporary_json = f"{json_file}.tmp.{os.getpid()}"

with open(temporary_json, "w", encoding="utf-8") as f:
    json.dump(inventory, f, indent=2, ensure_ascii=False)
    f.write("\n")

os.replace(temporary_json, json_file)
PY
}


generate_certificate_summary() {

    python3 - "$JSON_FILE" "$CERTIFICATES_FILE" <<'PY'
import json
import sys

json_file = sys.argv[1]
output_file = sys.argv[2]

with open(json_file, encoding="utf-8") as f:
    inventory = json.load(f)

lines = []

for host in inventory.get("hosts", []):

    for port in host.get("ports", []):

        cert = port.get("certificate_live", {})

        if not cert:
            continue

        days = cert.get("days_remaining")

        if isinstance(days, int):

            if days < 0:
                status = "EXPIRED"
            elif days <= 7:
                status = "CRITICAL"
            elif days <= 30:
                status = "WARNING"
            else:
                status = "OK"

        else:

            status = "UNKNOWN"

        lines.append(
            f"{host.get('ip','')}:{port.get('port','')} "
            f"{host.get('hostname','')} "
            f"status={status} "
            f"days_remaining={days} "
            f"subject={cert.get('subject','')} "
            f"issuer={cert.get('issuer','')} "
            f"not_after={cert.get('not_after','')} "
            f"san={','.join(cert.get('san', []))}"
        )

with open(output_file, "w", encoding="utf-8") as f:

    if lines:
        f.write("\n".join(lines) + "\n")
    else:
        f.write("No TLS certificates discovered.\n")
PY
}