// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "dependencies/forge-std-1.9.5/src/Script.sol";
import { IAssetManager } from "flare-periphery/src/coston2/IAssetManager.sol";
import { ContractRegistry } from "flare-periphery/src/coston2/ContractRegistry.sol";
import { IPayment } from "flare-periphery/src/coston2/IPayment.sol";
import { IFdcVerification } from "flare-periphery/src/coston2/IFdcVerification.sol";
import { Base as FdcBase } from "script/fdcExample/Base.s.sol";
import { Base as StringsBase } from "../../src/utils/fdcStrings/Base.sol";

// Run with commands
// solhint-disable-next-line max-line-length
// forge script script/fassets/FAssetsExecuteMinting.s.sol:ExecuteMinting --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract ExecuteMinting is Script {
    // Configuration constants
    uint256 public collateralReservationId = 24360013;
    uint256 public targetRoundId = 1074736;

    // FDC request data
    string public attestationType = "Payment";
    string public sourceId = "testXRP";
    string public urlType = "xrp";

    // Transaction data
    string public transactionId = "85B182F7B250BF8CB23531ECA5B508C0F66E8B7AEF7C8EE0CF851A7B2F8A9EB1";
    string public inUtxo = "0";
    string public utxo = "0";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get environment variables
        string memory verifierUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory verifierApiKey = vm.envString("VERIFIER_API_KEY_TESTNET");
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");

        require(bytes(verifierUrl).length > 0, "VERIFIER_URL_TESTNET env var not set");
        require(bytes(verifierApiKey).length > 0, "VERIFIER_API_KEY_TESTNET env var not set");
        require(bytes(daLayerUrl).length > 0, "COSTON2_DA_LAYER_URL env var not set");

        // Prepare FDC request
        string memory requestBody = string.concat(
            "{'transactionId':'",
            transactionId,
            "','inUtxo':'",
            inUtxo,
            "','utxo':'",
            utxo,
            "'}"
        );

        string memory url = string.concat(verifierUrl, "verifier/", urlType, "/Payment/prepareRequest");

        bytes memory abiEncodedRequest = FdcBase.prepareFdcRequest(url, attestationType, sourceId, requestBody);

        // Get proof from FDC

        IFdcVerification fdcVerification = ContractRegistry.getFdcVerification();
        uint8 protocolId = fdcVerification.fdcProtocolId();

        bytes memory proofData = FdcBase.retrieveProof(
            protocolId,
            StringsBase.toHexString(abiEncodedRequest),
            targetRoundId
        );

        // Parse the proof
        FdcBase.ParsableProof memory parsableProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IPayment.Response memory proofResponse = abi.decode(parsableProof.responseHex, (IPayment.Response));
        IPayment.Proof memory finalProof = IPayment.Proof(parsableProof.proofs, proofResponse);

        // Get FAssets FXRP asset manager
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();

        // Execute minting

        vm.startBroadcast(deployerPrivateKey);

        assetManager.executeMinting(finalProof, collateralReservationId);

        vm.stopBroadcast();
    }
}
