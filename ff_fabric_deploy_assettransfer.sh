#!/bin/bash

# https://hyperledger.github.io/firefly/tutorials/custom_contracts/fabric.html

cd ~/fabric-samples/asset-transfer-basic/chaincode-go
touch core.yaml
peer lifecycle chaincode package -p . --label asset_transfer ./asset_transfer.zip
ff deploy fabric dev asset_transfer.zip firefly asset_transfer 1.0
