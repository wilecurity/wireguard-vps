# WireGuard VPN Auto Setup

A lightweight Bash script that automates the deployment of a WireGuard VPN server on an Ubuntu VPS. The script installs the required packages, configures WireGuard, generates secure server and client key pairs, creates a client configuration file, and generates a QR code for quick setup on mobile devices.

## Features

* Automated WireGuard installation
* Automatic VPN server configuration
* Generates secure server and client key pairs
* Detects the VPS network interface automatically
* Configures UFW firewall rules
* Enables IPv4 packet forwarding
* Creates a client configuration file
* Generates a QR code for Android and iPhone WireGuard apps
* Beginner-friendly and easy to use

## Requirements

* Ubuntu 26.04 LTS,Ubuntu 24.04 LTS Or Ubuntu 22.04 LTS 
* Root or sudo privileges
* Public IPv4 address assigned to the VPS
* Internet connection

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/wireguard-vpn-auto-setup.git
cd wireguard-vpn-auto-setup
```

Make the script executable:

```bash
chmod +x install.sh
```

Run the installer:

```bash
sudo ./install.sh
```

During installation, you will be prompted for:

* Your VPS Public IP Address
* A name for the client device (e.g., iPhone, Android, Laptop)

Once the installation is complete, a WireGuard client configuration file will be generated and displayed as a QR code for quick import into the WireGuard mobile application.

## Output

The installer automatically creates:

* WireGuard server configuration
* Server private/public keys
* Client private/public keys
* Client configuration file
* QR Code for mobile devices

## Project Structure

```text
.
├── install.sh
├── README.md
└── LICENSE
```

Generated files:

```text
/etc/wireguard/
├── wg0.conf
├── iPhone.conf
└── keys/
    ├── server_private.key
    ├── server_public.key
    ├── iPhone_private.key
    └── iPhone_public.key
```

## Verify the VPN

Check the WireGuard status:

```bash
sudo wg show
```

Verify the service:

```bash
sudo systemctl status wg-quick@wg0
```

## Supported Clients

* Windows
* macOS
* Linux
* Android
* iPhone / iPad

## Troubleshooting

If clients connect but cannot access the internet:

* Verify that IPv4 forwarding is enabled.
* Confirm UDP port **51820** is open in your firewall.
* Verify the WireGuard service is running.
* Check the output of `sudo wg show` for successful handshakes.

## Security Notes

* Keep your server private key secret.
* Do not share client configuration files publicly.
* Restrict SSH access where possible.
* Keep your VPS updated with the latest security patches.


## Contributing

Contributions, improvements, and bug reports are welcome. Feel free to open an issue or submit a pull request.

## Disclaimer

This project is intended for educational purposes and for deploying your own VPN server for legitimate uses such as secure remote access and protecting your own network traffic. Users are responsible for complying with applicable laws, regulations, and their VPS provider's terms of service.
