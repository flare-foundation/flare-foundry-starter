// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
import {IAssetManager} from "flare-periphery/src/coston2/IAssetManager.sol";
import {ContractRegistry} from "flare-periphery/src/coston2/ContractRegistry.sol";
import {IPayment} from "flare-periphery/src/coston2/IPayment.sol";
import {IFdcVerification} from "flare-periphery/src/coston2/IFdcVerification.sol";
import {Base as FdcBase} from "script/fdcExample/Base.s.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";


// Run with commands
// forge script script/fassets/FAssetsExecuteMinting.s.sol:ExecuteMinting --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --ffi

contract ExecuteMinting is Script {
    // Configuration constants
    uint256 constant COLLATERAL_RESERVATION_ID = 24360013;
    uint256 constant TARGET_ROUND_ID = 1074736;
    
    // FDC request data
    string constant ATTESTATION_TYPE = "Payment";
    string constant SOURCE_ID = "testXRP";
    string constant URL_TYPE = "xrp";
    
    // Transaction data
    string constant TRANSACTION_ID = "85B182F7B250BF8CB23531ECA5B508C0F66E8B7AEF7C8EE0CF851A7B2F8A9EB1";
    string constant IN_UTXO = "0";
    string constant UTXO = "0";

    /**
     * @dev Convert bytes to hex string
     * @param data The bytes to convert
     * @return The hex string representation
     */
    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get environment variables
        string memory verifierUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory verifierApiKey = vm.envString("VERIFIER_API_KEY_TESTNET");
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        
        require(bytes(verifierUrl).length > 0, "VERIFIER_URL_TESTNET env var not set");
        require(bytes(verifierApiKey).length > 0, "VERIFIER_API_KEY_TESTNET env var not set");
        require(bytes(daLayerUrl).length > 0, "COSTON2_DA_LAYER_URL env var not set");

        console.log("Preparing FDC request...");
        
        // Prepare FDC request
        string memory requestBody = string.concat(
            '{"transactionId":"', TRANSACTION_ID, '","inUtxo":"', IN_UTXO, '","utxo":"', UTXO, '"}'
        );
        
        string memory url = string.concat(verifierUrl, "verifier/", URL_TYPE, "/Payment/prepareRequest");
        
        bytes memory abiEncodedRequest = FdcBase.prepareFdcRequest(
            url,
            ATTESTATION_TYPE,
            SOURCE_ID,
            requestBody
        );
        
        console.log("FDC request prepared successfully");

        // Get proof from FDC
        console.log("Retrieving proof from FDC...");
        IFdcVerification fdcVerification = ContractRegistry.getFdcVerification();
        uint8 protocolId = fdcVerification.fdcProtocolId();
        
        bytes memory proofData = FdcBase.retrieveProof(
            protocolId,
            toHexString(abiEncodedRequest),
            TARGET_ROUND_ID
        );
        
        console.log("Proof retrieved successfully");

        // Parse the proof
        FdcBase.ParsableProof memory parsableProof = abi.decode(proofData, (FdcBase.ParsableProof));
        IPayment.Response memory proofResponse = abi.decode(parsableProof.responseHex, (IPayment.Response));
        IPayment.Proof memory finalProof = IPayment.Proof(parsableProof.proofs, proofResponse);

        // Get FAssets FXRP asset manager
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        console.log("Asset manager address:", address(assetManager));

        // Execute minting
        console.log("Executing minting with collateral reservation ID:", COLLATERAL_RESERVATION_ID);
        vm.startBroadcast(deployerPrivateKey);
        
        assetManager.executeMinting(finalProof, COLLATERAL_RESERVATION_ID);
        
        vm.stopBroadcast();
        
        console.log("Minting executed successfully!");
    }
}
