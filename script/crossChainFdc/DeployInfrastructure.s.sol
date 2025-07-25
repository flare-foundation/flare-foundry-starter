// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AddressUpdater} from "../../src/crossChainFdc/AddressUpdater.sol";
import {FdcVerification} from "../../src/crossChainFdc/FdcVerification.sol";
import {IIAddressUpdatable} from "../../src/crossChainFdc/IIAddressUpdatable.sol";
import {CrossChainFdcConfig} from "./Config.s.sol";

// This script should be run on the TARGET non-Flare chain (e.g., XRPLEVM)
contract DeployInfrastructure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AddressUpdater
        AddressUpdater addressUpdater = new AddressUpdater(governance);
        console.log("AddressUpdater deployed to:", address(addressUpdater));

        // 2. Deploy FdcVerification
        // The FDC Protocol ID (200) is specific to the State Connector instance.
        FdcVerification fdcVerification = new FdcVerification(address(addressUpdater), 200);
        console.log("FdcVerification deployed to:", address(fdcVerification));

        // 3. Configure AddressUpdater with required contract names and addresses
        string[] memory names = new string[](2);
        address[] memory addresses = new address[](2);

        // Add the Relay contract
        names[0] = "Relay";
        addresses[0] = CrossChainFdcConfig.RELAY_ADDRESS;

        names[1] = "AddressUpdater";
        addresses[1] = address(addressUpdater);

        addressUpdater.addOrUpdateContractNamesAndAddresses(names, addresses);
        console.log("Registered 'Relay' and 'AddressUpdater' in AddressUpdater contract.");

        // 4. Update FdcVerification to know about the Relay
        IIAddressUpdatable[] memory contractsToUpdate = new IIAddressUpdatable[](1);
        contractsToUpdate[0] = fdcVerification;
        addressUpdater.updateContractAddresses(contractsToUpdate);
        console.log("FdcVerification contract has been updated with the latest addresses.");
        
        console.log("---");
        console.log("Infrastructure deployed. Please update script/crossChainFdc/Config.s.sol with these addresses:");
        console.log("ADDRESS_UPDATER:", address(addressUpdater));
        console.log("FDC_VERIFICATION:", address(fdcVerification));
        
        vm.stopBroadcast();
    }
}