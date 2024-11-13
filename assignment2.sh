#!/bin/bash

set -e

echo "Configuring network settings..."
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

# Backup existing config
sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
# Check if interface name is correct; update if necessary
INTERFACE_NAME="ens3"  # Confirm your interface name

# Backup existing config
if [ -f "$NETPLAN_FILE" ]; then
    sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
    echo "Backup of the original netplan configuration created."
fi
# Create new config
sudo tee "$NETPLAN_FILE" > /dev/null << EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      addresses: [192.168.16.21/24]
      routes:
        - to: default
          via: 192.168.16.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOL

sudo netplan apply

echo "Updating /etc/hosts..."
sudo sed -i '/^.*server1$/d' /etc/hosts
echo "192.168.16.21 server1" | sudo tee -a /etc/hosts

echo "Installing apache2 and squid..."
for i in {1..3}; do
    if sudo apt-get update && sudo apt-get install -y apache2 squid; then
        break
    fi
    echo "Attempt $i failed. Retrying in 5 seconds..."
    sleep 5
done

echo "Creating user accounts..."
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

for user in "${users[@]}"; do
    if ! id "$user" &>/dev/null; then
        sudo useradd -m -s /bin/bash "$user"
        echo "Created user: $user"
        
        sudo -u "$user" ssh-keygen -t rsa -N "" -f "/home/$user/.ssh/id_rsa"
        sudo -u "$user" ssh-keygen -t ed25519 -N "" -f "/home/$user/.ssh/id_ed25519"
        
        sudo -u "$user" touch "/home/$user/.ssh/authorized_keys"
        sudo -u "$user" cat "/home/$user/.ssh/id_rsa.pub" "/home/$user/.ssh/id_ed25519.pub" >> "/home/$user/.ssh/authorized_keys"
        
        if [ "$user" == "dennis" ]; then
            echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" | sudo tee -a "/home/$user/.ssh/authorized_keys"
            sudo usermod -aG sudo dennis
        fi
    else
        echo "User $user already exists."
    fi
done

echo "Configuration complete."
