#!/bin/sh

REMAPS='@openzeppelin=node_modules/@openzeppelin/ @ensdomains=node_modules/@ensdomains/ hardhat=node_modules/hardhat/ eth-gas-reporter=node_modules/eth-gas-reporter/ @rari-capital=node_modules/@rari-capital/'
# slither contracts/Tournament.sol --solc-disable-warnings --solc-remaps solc-remappings.txt

    #     --solc-remaps @openzeppelin=node_modules/@openzeppelin/ \
    # --solc-remaps @ensdomains=node_modules/@ensdomains/ \
    # --solc-remaps hardhat=node_modules/hardhat/ \
    # --solc-remaps eth-gas-reporter=node_modules/eth-gas-reporter/ \
    # --solc-remaps @rari-capital=node_modules/@rari-capital/ \



slither contracts/Tournament.sol --filter-paths 'console' --solc-remaps '@openzeppelin=node_modules/@openzeppelin/ @ensdomains=node_modules/@ensdomains/ hardhat=node_modules/hardhat/ eth-gas-reporter=node_modules/eth-gas-reporter/ @rari-capital=node_modules/@rari-capital/'
slither contracts/TournamentsFactory.sol --filter-paths 'console' --solc-remaps '@openzeppelin=node_modules/@openzeppelin/ @ensdomains=node_modules/@ensdomains/ hardhat=node_modules/hardhat/ eth-gas-reporter=node_modules/eth-gas-reporter/ @rari-capital=node_modules/@rari-capital/'