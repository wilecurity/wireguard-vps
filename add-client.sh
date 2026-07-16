#!/bin/bash

# ============================================
# ADD NEW WIREGUARD CLIENT
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     ADD NEW WIREGUARD CLIENT          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (sudo ./add-client.sh)${NC}"
    exit 1
fi

# Get VPS IP
echo -e "${YELLOW}📡 Enter your VPS Public IP:${NC}"
echo -n "   IP: "
read VPS_IP

if [[ ! $VPS_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid IP address!${NC}"
    exit 1
fi

# Get device name
echo -e "${YELLOW}📱 Enter device name:${NC}"
echo -n "   Name: "
read DEVICE_NAME

if [ -z "$DEVICE_NAME" ]; then
    echo -e "${RED}❌ Device name is required!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Device: $DEVICE_NAME${NC}"
echo ""

# Count existing clients
CLIENT_NUM=$(ls /etc/wireguard/keys/*_private.key 2>/dev/null | grep -v server | wc -l)
CLIENT_IP="10.0.0.$((CLIENT_NUM + 2))"

echo -e "${YELLOW}🔑 Generating keys for $DEVICE_NAME...${NC}"
cd /etc/wireguard/keys

# Generate client keys
CLIENT_PRIVATE=$(wg genkey)
CLIENT_PUBLIC=$(echo $CLIENT_PRIVATE | wg pubkey)
echo $CLIENT_PRIVATE > ${DEVICE_NAME}_private.key
echo $CLIENT_PUBLIC > ${DEVICE_NAME}_public.key

# Add to server
sudo tee -a /etc/wireguard/wg0.conf > /dev/null << EOF

[Peer]
PublicKey = $CLIENT_PUBLIC
AllowedIPs = ${CLIENT_IP}/32
EOF

# Restart WireGuard
systemctl restart wg-quick@wg0

# Get server public key
SERVER_PUB=$(cat server_public.key)

# Create client config
sudo tee /etc/wireguard/${DEVICE_NAME}.conf > /dev/null << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = ${CLIENT_IP}/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $VPS_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo ""
echo -e "${GREEN}✅ Client added!${NC}"
echo -e "${YELLOW}📋 Details:${NC}"
echo -e "   Device:     ${GREEN}$DEVICE_NAME${NC}"
echo -e "   VPN IP:     ${GREEN}$CLIENT_IP${NC}"
echo -e "   Config:     ${GREEN}/etc/wireguard/${DEVICE_NAME}.conf${NC}"
echo ""
echo -e "${YELLOW}📱 QR CODE:${NC}"
qrencode -t ansiutf8 < /etc/wireguard/${DEVICE_NAME}.conf
echo ""
echo -e "${YELLOW}📱 Config text:${NC}"
echo -e "${BLUE}---${NC}"
cat /etc/wireguard/${DEVICE_NAME}.conf
echo -e "${BLUE}---${NC}"
