#!/bin/bash



RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}     WIREGUARD VPN SETUP (COMPLETE)    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# CHECK: Run as root
# ============================================
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (sudo ./setup-wireguard.sh)${NC}"
    exit 1
fi

# ============================================
# STEP 1: Get VPS Public IP
# ============================================
echo -e "${YELLOW}📡 Enter your VPS Public IP Address:${NC}"
echo -e "${GREEN}   (Example: 162.35.173.170)${NC}"
echo -n "   IP: "
read VPS_IP

if [[ ! $VPS_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid IP address format!${NC}"
    echo -e "${YELLOW}Please enter a valid IPv4 address (e.g., 162.35.173.170)${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Using IP: $VPS_IP${NC}"
echo ""

# ============================================
# STEP 2: Get Device Name
# ============================================
echo -e "${YELLOW}📱 Enter device name (e.g., iPhone, Laptop, Android):${NC}"
echo -n "   Name [default: iPhone]: "
read DEVICE_NAME
[ -z "$DEVICE_NAME" ] && DEVICE_NAME="iPhone"
echo -e "${GREEN}✅ Device: $DEVICE_NAME${NC}"
echo ""

# ============================================
# STEP 3: Detect Network Interface
# ============================================
echo -e "${YELLOW}🔍 Detecting network interface...${NC}"
INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$INTERFACE" ]; then
    echo -e "${RED}❌ Could not detect network interface!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Interface: $INTERFACE${NC}"
echo ""

# ============================================
# STEP 4: Install WireGuard
# ============================================
echo -e "${YELLOW}📦 Updating packages and installing WireGuard...${NC}"
apt update -qq
apt install wireguard iptables qrencode ufw curl -y -qq
echo -e "${GREEN}✅ WireGuard installed!${NC}"
echo ""

# ============================================
# STEP 5: ENABLE IP FORWARDING (CRITICAL FIX!)
# ============================================
echo -e "${YELLOW}🔧 Enabling IP forwarding (CRITICAL!)...${NC}"

# Remove ALL existing net.ipv4.ip_forward lines (including commented ones)
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.d/*.conf 2>/dev/null

# Add the correct value
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Apply immediately
sysctl -p > /dev/null 2>&1

# VERIFY it worked
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}✅ IP forwarding ENABLED (value: $IP_FORWARD)${NC}"
else
    echo -e "${RED}❌ CRITICAL ERROR: IP forwarding is still $IP_FORWARD!${NC}"
    echo -e "${YELLOW}   Trying direct method...${NC}"
    
    # Direct kernel method
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$IP_FORWARD" = "1" ]; then
        echo -e "${GREEN}✅ IP forwarding manually ENABLED${NC}"
    else
        echo -e "${RED}❌ FAILED to enable IP forwarding!${NC}"
        echo -e "${YELLOW}   Please check: /etc/sysctl.conf${NC}"
        echo -e "${YELLOW}   Also check if your VPS provider blocks this${NC}"
        exit 1
    fi
fi
echo ""

# ============================================
# STEP 6: Configure Firewall (UFW)
# ============================================
echo -e "${YELLOW}🔒 Configuring firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 51820/udp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1
ufw reload > /dev/null 2>&1
echo -e "${GREEN}✅ Firewall configured (ports 22/tcp, 51820/udp open)${NC}"
echo ""

# ============================================
# STEP 7: Create Keys
# ============================================
echo -e "${YELLOW}🔑 Generating cryptographic keys...${NC}"
mkdir -p /etc/wireguard/keys
cd /etc/wireguard/keys

# Server keys
SERVER_PRIVATE=$(wg genkey)
SERVER_PUBLIC=$(echo $SERVER_PRIVATE | wg pubkey)
echo $SERVER_PRIVATE > server_private.key
echo $SERVER_PUBLIC > server_public.key

# Client keys
CLIENT_PRIVATE=$(wg genkey)
CLIENT_PUBLIC=$(echo $CLIENT_PRIVATE | wg pubkey)
echo $CLIENT_PRIVATE > ${DEVICE_NAME}_private.key
echo $CLIENT_PUBLIC > ${DEVICE_NAME}_public.key

echo -e "${GREEN}✅ Keys generated${NC}"
echo ""

# ============================================
# STEP 8: Create Server Config
# ============================================
echo -e "${YELLOW}📝 Creating server configuration...${NC}"
sudo tee /etc/wireguard/wg0.conf > /dev/null << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
EOF

# Add client
sudo tee -a /etc/wireguard/wg0.conf > /dev/null << EOF

[Peer]
PublicKey = $CLIENT_PUBLIC
AllowedIPs = 10.0.0.2/32
EOF

echo -e "${GREEN}✅ Server configuration created${NC}"
echo ""

# ============================================
# STEP 9: Enable and Start WireGuard
# ============================================
echo -e "${YELLOW}🚀 Starting WireGuard service...${NC}"
systemctl start wg-quick@wg0
systemctl enable wg-quick@wg0 2>/dev/null

sleep 2
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✅ WireGuard is running!${NC}"
else
    echo -e "${RED}❌ Failed to start WireGuard!${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    journalctl -u wg-quick@wg0 -n 10
    exit 1
fi
echo ""

# ============================================
# STEP 10: Create Client Config
# ============================================
echo -e "${YELLOW}📱 Creating client configuration...${NC}"
sudo tee /etc/wireguard/${DEVICE_NAME}.conf > /dev/null << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = 10.0.0.2/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $VPS_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo -e "${GREEN}✅ Client configuration created${NC}"
echo ""

# ============================================
# STEP 11: VERIFY EVERYTHING
# ============================================
echo -e "${YELLOW}🔍 Running verification checks...${NC}"

# Check IP forwarding
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}   ✅ IP Forwarding: $IP_FORWARD${NC}"
else
    echo -e "${RED}   ❌ IP Forwarding: $IP_FORWARD (should be 1!)${NC}"
fi

# Check WireGuard
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}   ✅ WireGuard: Running${NC}"
else
    echo -e "${RED}   ❌ WireGuard: Not running${NC}"
fi

# Check firewall
if ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}   ✅ Firewall: Active${NC}"
else
    echo -e "${YELLOW}   ⚠️  Firewall: Inactive${NC}"
fi

# Check if port is listening
if ss -ulnp | grep -q "51820"; then
    echo -e "${GREEN}   ✅ Port 51820: Listening${NC}"
else
    echo -e "${RED}   ❌ Port 51820: Not listening${NC}"
fi
echo ""

# ============================================
# STEP 12: Display Results
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ SETUP COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📋 CONFIGURATION SUMMARY:${NC}"
echo -e "   Server IP:     ${GREEN}$VPS_IP${NC}"
echo -e "   Server Port:   ${GREEN}51820${NC}"
echo -e "   Device Name:   ${GREEN}$DEVICE_NAME${NC}"
echo -e "   VPN IP:        ${GREEN}10.0.0.2${NC}"
echo -e "   IP Forwarding: ${GREEN}ENABLED (1) ✅${NC}"
echo -e "   Config File:   ${GREEN}/etc/wireguard/${DEVICE_NAME}.conf${NC}"
echo -e "   Server Status: ${GREEN}Running ✅${NC}"
echo ""
echo -e "${YELLOW}📱 SCAN THIS QR CODE ON YOUR DEVICE:${NC}"
echo ""
qrencode -t ansiutf8 < /etc/wireguard/${DEVICE_NAME}.conf
echo ""
echo -e "${YELLOW}📱 OR copy this config manually:${NC}"
echo -e "${BLUE}---${NC}"
cat /etc/wireguard/${DEVICE_NAME}.conf
echo -e "${BLUE}---${NC}"
echo ""
echo -e "${YELLOW}🔍 Check connection with:${NC}"
echo -e "   ${GREEN}sudo wg show${NC}"
echo ""
echo -e "${YELLOW}📌 To add more devices:${NC}"
echo -e "   ${GREEN}./add-client.sh${NC}"
echo -e "${BLUE}========================================${NC}"
