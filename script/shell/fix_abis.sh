echo "Starting script with removing artifacts/contracts"
rm -rf ./artifacts/contracts/
echo "Deploying contracts and compiling"
npx hardhat compile --force
npx hardhat run --network localhost scripts/deploy.js

# THIS IS FOR THE UI
echo "Removing tournaments ui ABI file"
rm -rf ../tournaments-ui/src/abi

echo "Replacting it"
cp -r ./artifacts/contracts ../tournaments-ui/src/abi

## THIS IS FOR BROWNIE
# echo "Removing python-oracle ABI file"
# rm -rf ../python-oracle/contracts/
# echo "Replacting it"
# cp -r ./artifacts/contracts ../python-oracle/abi/

## Remember to reset the factory address in the python oracle and also the react app