#!/bin/bash

# https://hyperledger.github.io/firefly/tutorials/custom_contracts/fabric.html

# Config
GREEN='\033[0;32m'
NC='\033[0m'

# Starting message
echo -e "${GREEN}FireFly with Fabric || AssetTransfer deploying is about to start in 5 seconds...${NC}"
echo -e "${GREEN}to cancel CTRL+C${NC}"
sleep 5

# Create core.yml
cd ~/fabric-samples/asset-transfer-basic/chaincode-go
touch core.yaml

# Replace smartcontract.go with edited version
cd chaincode
rm smartcontract.go
curl -sSLO https://raw.githubusercontent.com/cagatayuresin/firefly-with-fabric/main/smartcontract.go
cd ..

# Create deployment pack for assetTransfer
rm asset_transfer.zip
peer lifecycle chaincode package -p . --label asset_transfer ./asset_transfer.zip

# Starting message
echo -e "${GREEN}If everything seems ok the FireFly stack is going to start in 5 seconds.${NC}"
sleep 5

# Deploy
ff deploy fabric dev asset_transfer.zip firefly asset_transfer 1.0
