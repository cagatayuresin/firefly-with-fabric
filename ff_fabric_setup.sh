#!/bin/bash

# Lookup Table
FABRIC_CLI_PACK_URL="https://github.com/hyperledger/firefly-cli/releases/download/v1.2.2/firefly-cli_1.2.2_Linux_x86_64.tar.gz"

# Config
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Standart initialization
sudo apt update
sudo apt upgrade -y
sudo apt install unattended-upgrades -y
sudo apt autoremove -y

# Installation of essentials
sudo apt install -y git curl docker-compose jq wget

# Little Docker configuration
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker "$USER"

# Easy mod of go installation
sudo snap install go --classic

# Getting Fabric installation script
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh
./install-fabric.sh docker samples binary # Installing Fabric requirements

# Check if it's OK
export PATH="$PATH:$HOME/fabric-samples/bin"
if command -v peer &> /dev/null; then
    echo -e "${GREEN}Fabric binaries successfully installed!${NC}"
else
    echo -e "${RED}ERROR: Fabric binaries could not be successfully added to PATH!${NC}"
    exit 1
fi

# Get FireFly CLI pack
cd Downloads

# Check if it's OK
wget "$FABRIC_CLI_PACK_URL"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}The FireFly CLI pack has been downloaded successfully.${NC}"
else
    echo -e "${RED}ERROR: FireFly CLI pack could not be downloaded!${NC}"
    cd ~
    exit 1
fi

# Unpack FireFly then add PATH
sudo tar -zxf firefly-cli_*.tar.gz -C /usr/local/bin ff
rm firefly-cli_*.tar.gz
cd ~

# Check if it's OK
ff version
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Firefly CLI has been successfully installed and working.${NC}"
else
    echo -e "${RED}ERROR: Firefly CLI failed to install successfully!${NC}"
    exit 1
fi

# Get FireFly repository
git clone https://github.com/hyperledger/firefly.git

# Start Fabric test network
cd fabric-samples/test-network
./network.sh up createChannel -ca

# Deploy FireFly Chaincode
cd ../../firefly/smart_contracts/fabric/firefly-go
GO111MODULE=on go mod vendor
cd ../../../../fabric-samples/test-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/

peer lifecycle chaincode package firefly.tar.gz --path ../../firefly/smart_contracts/fabric/firefly-go --lang golang --label firefly_1.0

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install firefly.tar.gz

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install firefly.tar.gz

export CC_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq --raw-output ".installed_chaincodes[0].package_id")

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name firefly --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name firefly --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name firefly --version 1.0 --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

# Getting CCP Templates
cd ~
