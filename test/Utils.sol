// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {FlareContractsRegistryLibrary} from "lib/flare-foundry-periphery-package/src/coston2/util-contracts/ContractRegistryLibrary.sol";
import {FlareContractRegistryMock} from "lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFlareContractRegistry.sol";

library Utils {
    function deployFlareContractRegistryMock(
        Vm vm,
        bool strict
    ) internal returns (FlareContractRegistryMock) {
        vm.prank(0x383A7bD61490EbaC078CB420B326FCE264042d19);

        FlareContractRegistryMock registry = new FlareContractRegistryMock(
            strict
        );

        require(
            address(registry) ==
                FlareContractsRegistryLibrary.FLARE_CONTRACT_REGISTRY_ADDRESS,
            "FlareContractRegistry was not deployed at the correct address"
        );

        return registry;
    }
}
