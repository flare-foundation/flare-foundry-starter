// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {FlareContractsRegistryLibrary} from "lib/flare-foundry-periphery-package/src/coston2/util-contracts/ContractRegistryLibrary.sol";
import {FlareContractRegistryMock} from "lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFlareContractRegistry.sol";
import {Utils} from "./Utils.sol";

import {SimpleFtsoExample} from "../src/SimpleFtsoExample.sol";
import {Mock} from "../src/Mock.sol";

contract TestSimpleFtsoExample is Test {
    FlareContractRegistryMock registryMock;
    SimpleFtsoExample ftsoExample;

    function setUp() public {
        registryMock = Utils.deployFlareContractRegistryMock(vm, true);

        string[] memory contracts = new string[](1);
        contracts[0] = "FtsoRegistry";

        address[] memory addresses = new address[](1);
        addresses[0] = address(new Mock());

        registryMock.update(contracts, addresses);

        ftsoExample = new SimpleFtsoExample();
    }

    function testSimplePrice() public {
        bytes memory callData = abi.encodeWithSelector(
            bytes4(keccak256("getCurrentPriceWithDecimals(string)")),
            "BTC"
        );

        vm.mockCall(
            address(FlareContractsRegistryLibrary.getFtsoRegistry()),
            callData,
            abi.encode(1, 2, 3)
        );

        (uint256 _price, uint256 _timestamp, uint256 _decimals) = ftsoExample
            .getCurrentTokenPriceWithDecimals("BTC");

        assertEq(_price, 1, "Wrong price");
        assertEq(_timestamp, 2, "Wrong timestamp");
        assertEq(_decimals, 3, "Wrong decimals");
    }

    function testRatio() public {
        bytes memory callData1 = abi.encodeWithSelector(
            bytes4(keccak256("getCurrentPriceWithDecimals(string)")),
            "BTC"
        );

        vm.mockCall(
            address(FlareContractsRegistryLibrary.getFtsoRegistry()),
            callData1,
            abi.encode(10, 0, 5)
        );
        bytes memory callData2 = abi.encodeWithSelector(
            bytes4(keccak256("getCurrentPriceWithDecimals(string)")),
            "LTC"
        );

        vm.mockCall(
            address(FlareContractsRegistryLibrary.getFtsoRegistry()),
            callData2,
            abi.encode(200, 0, 6)
        );

        (uint256 _price1, uint256 _price2, bool _is_higher) = ftsoExample
            .isPriceRatioHigherThan("BTC", "LTC", 999, 2000);

        assertEq(_price1, 1 * 10 ** 14, "Wrong price1");
        assertEq(_price2, 2 * 10 ** 14, "Wrong price2");
        assertTrue(_is_higher, "Wrong is_higher");
    }
}
