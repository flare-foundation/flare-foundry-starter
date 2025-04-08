// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {Test} from "dependencies/forge-std-1.9.5/src/Test.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {IEVMTransaction} from "dependencies/flare-periphery-0.0.22/src/coston2/IEVMTransaction.sol";
import {FdcStrings} from "src/utils/fdcStrings/EVMTransaction.sol";
import {Base} from "src/utils/fdcStrings/Base.sol";

contract TestFdcStrings is Test {
    function test_toString_bool() public pure {
        string memory got1 = Base.toString(true);
        string memory expected1 = "true";
        string memory got2 = Base.toString(false);
        string memory expected2 = "false";
        require(
            Strings.equal(got1, expected1),
            string.concat("Expected: ", expected1, ", got:", got1)
        );
        require(
            Strings.equal(got2, expected2),
            string.concat("Expected: ", expected2, ", got:", got2)
        );
    }

    struct TestReq {
        bytes32 attestationType;
        bytes32 sourceId;
        bytes32 messageIntegrityCode;
        RequestBody requestBody;
    }

    struct RequestBody {
        bytes32 transactionHash;
        // BUG uint256 works, but uint32 does not
        uint256 requiredConfirmations;
        bool provideInput;
        bool listEvents;
        // BUG this still doesn't work
        uint256[] logIndices;
    }
    function test_toString_Request() public view {
        // TODO: Implement this test
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/test/utils/examples/IEVMTransaction/Request.json"
        );
        string memory got1 = vm.readFile(path);
        bytes memory data = vm.parseJson(got1);
        TestReq memory request = abi.decode(data, (TestReq));

        // IEVMTransaction.Request memory request = abi.decode(
        //     data,
        //     (IEVMTransaction.Request)
        // );
        // string memory expected1 = FdcStrings.toString(request);
        // require(
        //     Strings.equal(got1, expected1),
        //     string.concat("Expected: ", expected1, ", got:", got1)
        // );
    }
}
