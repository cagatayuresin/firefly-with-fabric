#!/bin/bash

# https://hyperledger.github.io/firefly/tutorials/custom_contracts/fabric.html

# Lookup Table
FABRIC_TEST_NETWORK="$HOME/fabric-samples/test-network"
ORGANIZATIONS="$FABRIC_TEST_NETWORK/organizations"
FABRIC_BINS=$HOME/fabric-sambles/bin

# Config
GREEN='\033[0;32m'
NC='\033[0m'
export PATH="$PATH:$FABRIC_BINS"
export FABRIC_CFG_PATH=$HOME/fabric-samples/config/
export CORE_PEER_TLS_ENABLED=true

# Starting message
echo -e "${GREEN}FireFly with Fabric || AssetTransfer deploying is about to start in 5 seconds...${NC}"
echo -e "${GREEN}to cancel CTRL+C${NC}"
sleep 5

# Create core.yml
cd $HOME/fabric-samples/asset-transfer-basic/chaincode-go
touch core.yaml

# Replace smartcontract.go with edited version
cd chaincode
rm smartcontract.go
curl -sSLO https://raw.githubusercontent.com/cagatayuresin/firefly-with-fabric/main/smartcontract.go
cd ..

# Create deployment pack for assetTransfer
GO111MODULE=on go mod vendor
peer lifecycle chaincode package -p $HOME/fabric-samples/asset-transfer-basic/chaincode-go/ --label asset_transfer $HOME/asset_transfer.zip
cd $FABRIC_TEST_NETWORK

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$ORGANIZATIONS/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$ORGANIZATIONS/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install asset_transfer.zip

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$ORGANIZATIONS/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$ORGANIZATIONS/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install asset_transfer.zip
echo $(peer lifecycle chaincode queryinstalled --output json | jq --raw-output ".installed_chaincodes")
export CC_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq --raw-output ".installed_chaincodes[1].package_id")

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset_transfer --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "$ORGANIZATIONS/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=$ORGANIZATIONS/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=$ORGANIZATIONS/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset_transfer --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "$ORGANIZATIONS/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name asset_transfer --version 1.0 --sequence 1 --tls --cafile "$ORGANIZATIONS/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" --peerAddresses localhost:7051 --tlsRootCertFiles "$ORGANIZATIONS/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "$ORGANIZATIONS/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

# Starting message
echo -e "${GREEN}If everything seems ok the FireFly stack is going to start in 5 seconds.${NC}"
sleep 5

# Deploy
ff deploy fabric dev asset_transfer.zip firefly asset_transfer 1.0
