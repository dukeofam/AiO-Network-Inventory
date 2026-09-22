#!/usr/bin/env bash

compare_previous_scan() {

    if [[ ! -L "$LATEST_LINK" ]]; then

        echo "First scan - no previous inventory available." \
            > "$CHANGES_FILE"

        return

    fi

    local previous_target previous_dir

    previous_target="$(readlink "$LATEST_LINK")"
    previous_dir="$(cd -P "$(dirname "$LATEST_LINK")/${previous_target}" && pwd)"

    local previous_json="${previous_dir}/inventory.json"

    if [[ ! -f "$previous_json" ]]; then

        echo "Previous inventory not found." \
            > "$CHANGES_FILE"

        return

    fi

    log "Comparing current scan with previous scan..."

    python3 - \
        "$previous_json" \
        "$JSON_FILE" \
        "$CHANGES_FILE" <<'PY'

import json
import sys

old_file = sys.argv[1]
new_file = sys.argv[2]
output_file = sys.argv[3]


def load(filename):

    with open(filename, encoding="utf-8") as f:
        data = json.load(f)

    result = {}

    for host in data.get("hosts", []):

        ip = host.get("ip", "")

        ports = set()

        for port in host.get("ports", []):

            ports.add(
                (
                    int(port.get("port", 0)),
                    port.get("protocol", "tcp")
                )
            )

        result[ip] = {
            "hostname": host.get(
                "hostname",
                ""
            ),
            "os": host.get(
                "os",
                ""
            ),
            "ports": ports
        }

    return result


old = load(old_file)
new = load(new_file)

changes = []

old_ips = set(old)
new_ips = set(new)


# ------------------------------------------------------------
# Hosts
# ------------------------------------------------------------

for ip in sorted(new_ips - old_ips):

    changes.append(
        f"[NEW HOST] "
        f"{ip} "
        f"{new[ip]['hostname']}"
    )


for ip in sorted(old_ips - new_ips):

    changes.append(
        f"[REMOVED HOST] "
        f"{ip} "
        f"{old[ip]['hostname']}"
    )


# ------------------------------------------------------------
# Existing hosts
# ------------------------------------------------------------

for ip in sorted(old_ips & new_ips):

    added = (
        new[ip]["ports"]
        - old[ip]["ports"]
    )

    removed = (
        old[ip]["ports"]
        - new[ip]["ports"]
    )

    for port, protocol in sorted(added):

        changes.append(
            f"[NEW PORT] "
            f"{ip} "
            f"{port}/{protocol}"
        )

    for port, protocol in sorted(removed):

        changes.append(
            f"[REMOVED PORT] "
            f"{ip} "
            f"{port}/{protocol}"
        )


with open(
    output_file,
    "w",
    encoding="utf-8"
) as f:

    if changes:

        f.write(
            "\n".join(changes)
            + "\n"
        )

    else:

        f.write(
            "No infrastructure changes detected.\n"
        )

print(
    f"Changes detected: {len(changes)}"
)

PY
}