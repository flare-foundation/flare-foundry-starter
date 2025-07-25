// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// This file holds the addresses of the deployed infrastructure on the target chain (e.g., Coston2).
// UPDATE THESE ADDRESSES after running the DeployInfrastructure.s.sol script.
library CrossChainFdcConfig {
    // A known, relayed version of the Relay contract on the target chain.
    // For XRPLEVM (in this example), the Relay contract is deployed at this address:
    address constant RELAY_ADDRESS = 0x72A35A930e2a35198FE8dEFf40e068B8D4b6CC78; 
    
    // TODO: UPDATE THESE AFTER DEPLOYING INFRASTRUCTURE SCRIPT IS RUN
    address constant ADDRESS_UPDATER = 0xa8193b3B94CF7Cfd7f1Dea1f18FDFb34D5eD704A;
    address constant FDC_VERIFICATION = 0x72DA85B87CC9FdD2431df304FaE03e27a27DA5Fb;
}