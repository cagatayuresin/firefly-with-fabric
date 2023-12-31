#!/bin/bash

# https://hyperledger.github.io/firefly/tutorials/chains/fabric_test_network.html
# https://hyperledger-fabric.readthedocs.io/en/release-2.5/getting_started.html

# Lookup Table
FABRIC_TEST_NETWORK="$HOME/fabric-samples/test-network"
ORGANIZATIONS="$FABRIC_TEST_NETWORK/organizations"
FIREFLY_CLI_PACK_URL="https://github.com/hyperledger/firefly-cli/releases/download/v1.2.2/firefly-cli_1.2.2_Linux_x86_64.tar.gz"
ORG1_USER_KEYSTORE_DIR="$ORGANIZATIONS/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/"
ORG2_USER_KEYSTORE_DIR="$ORGANIZATIONS/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/keystore/"
ORDERER_KEYSTORE_DIR="$ORGANIZATIONS/fabric-ca/ordererOrg/msp/keystore"
FABRIC_BINS=$HOME/fabric-sambles/bin

# Config
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Starting message
echo -e "${GREEN}FireFly with Fabric || Setup is about to start in 5 seconds...${NC}"
echo -e "${GREEN}to cancel CTRL+C${NC}"
sleep 5

# Standart initialization
sudo apt update
sudo apt upgrade -y
sudo apt install unattended-upgrades -y

# Installation of essentials
sudo apt install -y git jq wget

# Easy mod of go installation
sudo snap install go --classic

# Getting Fabric installation script
curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh
./install-fabric.sh docker samples binary # Installing Fabric requirements

# Check if it's OK
export PATH="$PATH:$FABRIC_BINS"
if command -v peer &> /dev/null; then
    echo -e "${GREEN}Fabric binaries successfully installed!${NC}"
else
    echo -e "${RED}ERROR: Fabric binaries could not be successfully added to PATH!${NC}"
    exit 1
fi

# Get FireFly CLI pack
cd Downloads

# Check if it's OK
wget "$FIREFLY_CLI_PACK_URL"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}The FireFly CLI pack has been downloaded successfully.${NC}"
else
    echo -e "${RED}ERROR: FireFly CLI pack could not be downloaded!${NC}"
    cd $HOME
    exit 1
fi

# Unpack FireFly then add PATH
sudo tar -zxf firefly-cli_*.tar.gz -C /usr/local/bin ff
rm firefly-cli_*.tar.gz
cd $HOME

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
sudo chmod +x network.sh
./network.sh down
sleep 1
./network.sh up createChannel -ca

# Deploy FireFly Chaincode
cd $HOME/firefly/smart_contracts/fabric/firefly-go
GO111MODULE=on go mod vendor
cd $FABRIC_TEST_NETWORK

export FABRIC_CFG_PATH=$FABRIC_TEST_NETWORK/../config/

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
cd $HOME
curl -sSLO https://raw.githubusercontent.com/cagatayuresin/firefly-with-fabric/main/org1_ccp.yml
curl -sSLO https://raw.githubusercontent.com/cagatayuresin/firefly-with-fabric/main/org2_ccp.yml

# Print keystore keys
echo -e "${GREEN}Please replace the string FILL_IN_KEY_NAME_HERE with these keys (ONLY KEY) in org1_ccp.yml and org2_ccp.yml${NC}"
echo -e "${YELLOW}Org1 Key: $(ls "$ORG1_USER_KEYSTORE_DIR")${NC}"
echo -e "${YELLOW}Org2 Key: $(ls "$ORG2_USER_KEYSTORE_DIR")${NC}"
# Waiting the user for key replacement
read -p "I am waiting... Did you do replacement? (y/N) " answer
if [[ $answer == "y" ]]; then
  echo -e "${GREEN}IN PROGRESS...${NC}"
else
  echo -e "${RED}ERROR: I cannot go on!${NC}"
  exit 1
fi

# Stop and remove dev stack on FireFly if it is exist
cd $FABRIC_TEST_NETWORK
ff stop dev
echo "y" | ff remove dev

# Initialization FireFly Fabric stack as dev
sudo chmod -R 777 $FABRIC_TEST_NETWORK
cd $FABRIC_TEST_NETWORK
ff init fabric dev --ccp "$HOME/org1_ccp.yml" --msp "organizations" --ccp "$HOME/org2_ccp.yml" --msp "organizations" --channel mychannel --chaincode firefly

# Replace docker-compose.override.yml with edited version
cd $HOME/.firefly/stacks/dev/
sudo rm docker-compose.override.yml
curl -sSLO https://raw.githubusercontent.com/cagatayuresin/firefly-with-fabric/main/docker-compose.override.yml


# Starting message
echo -e "${GREEN}If everything seems ok the FireFly stack is going to start in 5 seconds.${NC}"
sleep 5

# Start FireFly Fabric stack that named dev
ff start dev --verbose --no-rollback

exit 1