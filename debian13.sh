
#!/usr/bin/env bash
set -Eeuo pipefail

# Prepare a Debian Proxmox VM for use as a template.
# Run as root, after cloud-init has finished its initial setup.

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

CFG="/etc/cloud/cloud.cfg"

if [[ ! -f "$CFG" ]]; then
    echo "ERROR: $CFG not found."
    exit 1
fi

echo "==> Removing unwanted cloud-init modules..."

# Only edit entries inside cloud_final_modules.
python3 - "$CFG" <<'PY'
import re
import sys

path = sys.argv[1]
remove = {
    "byobu",
    "landscape",
    "puppet",
    "chef",
    "mcollective",
    "salt-minion",
}

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

inside = False
found = set()
result = []

for line in lines:
    if re.match(r"^cloud_final_modules\s*:", line):
        inside = True
        result.append(line)
        continue

    if inside and line.strip() and not line[0].isspace():
        inside = False

    if inside:
        match = re.match(r"^\s*-\s+([a-zA-Z0-9_-]+)\s*(?:#.*)?$", line)
        if match and match.group(1) in remove:
            found.add(match.group(1))
            continue

    result.append(line)

if not any(re.match(r"^cloud_final_modules\s*:", x) for x in lines):
    sys.exit("ERROR: cloud_final_modules section not found.")

with open(path, "w", encoding="utf-8") as f:
    f.writelines(result)

print("Removed:", ", ".join(sorted(found)) if found else "No matching entries found")
PY

echo "==> Updating package lists..."
export DEBIAN_FRONTEND=noninteractive
apt update

echo "==> Installing required packages..."
apt install -y --no-install-recommends \
    qemu-guest-agent \
    curl \
    git \
    whois \
    wget


# Remove anything conflicting with docker
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc | cut -f1)

echo "==> Enabling QEMU guest agent..."
systemctl enable qemu-guest-agent.service
systemctl start qemu-guest-agent.service

echo "==> Cleaning package cache..."
apt clean
rm -rf /var/lib/apt/lists/*

echo "==> Clearing system journal..."
journalctl --rotate
journalctl --vacuum-time=1s

echo "==> Clearing regular log files..."
find /var/log -type f \
    ! -path '/var/log/journal/*' \
    -exec truncate -s 0 {} +

# Remove temporary files
rm -rf /tmp/* /var/tmp/*

# If using DHCP, remove leases
rm -f /var/lib/dhcp/*.leases

# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Remove SSH host keys (will be regenerated on next boot)
rm -f /etc/ssh/ssh_host_*

echo "==> Resetting machine ID..."
# Clear the machine-id (will be regenerated on next boot)
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Restore the conventional Debian/DBus machine-id link.
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo "==> VM preparation complete. Powering off..."
systemctl poweroff
