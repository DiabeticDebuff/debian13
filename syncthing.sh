# Add the release PGP keys:
mkdir -p /etc/apt/keyrings
curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg


# Add the "stable-v2" channel to your APT sources:
echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list


# Update and install syncthing:
apt-get update
apt-get install syncthing

systemctl enable --now syncthing@"$USER".service


systemctl status syncthing@"$USER".service