// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-periphery/src/coston2/IWeb2Json.sol";

interface IJsonApiVerificationOther {
    function verifyJsonApi(
        IWeb2Json.Proof calldata _proof
    ) external payable returns (bool _proved);
}
