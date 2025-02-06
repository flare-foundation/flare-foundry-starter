// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.25;

// import {console} from "dependencies/forge-std-1.9.5/src/console.sol";
// import {Script} from "dependencies/forge-std-1.9.5/src/Script.sol";
// import {Surl} from "dependencies/surl-0.0.0/src/Surl.sol";
// import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
// import {ContractRegistry} from "dependencies/flare-periphery-0.0.1/src/coston2/ContractRegistry.sol";
// import {IFdcHub} from "dependencies/flare-periphery-0.0.1/src/coston2/IFdcHub.sol";
// import {IFlareSystemsManager} from "dependencies/flare-periphery-0.0.1/src/coston2/IFlareSystemsManager.sol";
// import {IReferencedPaymentNonexistence} from "dependencies/flare-periphery-0.0.1/src/coston2/IReferencedPaymentNonexistence.sol";
// import {TransferEventListener} from "src/FdcTransferEventListener.sol";
// import {Base as StringsBase} from "src/utils/fdcStrings/Base.sol";
// import {FdcStrings} from "src/utils/fdcStrings/ReferencedPaymentNonexistence.sol";
// import {Base} from "./Base.s.sol";

// string constant attestationTypeName = "ReferencedPaymentNonexistence";
// string constant dirPath = "data/";

// // Run with command
// //      forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:PrepareAttestationRequest --rpc-url $COSTON2_RPC_URL --ffi

// contract PrepareAttestationRequest is Script {
//     using Surl for *;

//     // Setting request data
//     string public minimalBlockNumber = "TODO";
//     string public deadlineBlockNumber = "TODO";
//     string public deadlineTimestamp = "TODO";
//     string public destinationAddressHash = "TODO";
//     string public amount = "TODO";
//     string public standardPaymentReference = "TODO";
//     string public checkSourceAddresses = "TODO";
//     string public sourceAddressesRoot = "TODO";
//     string public baseSourceName = "btc"; // Part of verifier URL
//     string public sourceName = "testBTC"; // Bitcoin chain ID

//     function prepareRequestBody(
//         string memory minimalBlockNumber,
//         string memory deadlineBlockNumber,
//         string memory deadlineTimestamp,
//         string memory destinationAddressHash,
//         string memory amount,
//         string memory standardPaymentReference,
//         string memory checkSourceAddresses,
//         string memory sourceAddressesRoot
//     ) private pure returns (string memory) {
//         return
//             string.concat(
//                 '{"minimalBlockNumber": "',
//                 minimalBlockNumber,
//                 '","deadlineBlockNumber": "',
//                 deadlineBlockNumber,
//                 '","deadlineTimestamp": "',
//                 deadlineTimestamp,
//                 '","destinationAddressHash": "',
//                 destinationAddressHash,
//                 '","amount": "',
//                 amount,
//                 '","standardPaymentReference": "',
//                 standardPaymentReference,
//                 '","checkSourceAddresses": "',
//                 checkSourceAddresses,
//                 '","sourceAddressesRoot": "',
//                 sourceAddressesRoot,
//                 '"}'
//             );
//     }

//     function run() external {
//         // Preparing request data
//         string memory attestationType = Base.toUtf8HexString(
//             attestationTypeName
//         );
//         string memory sourceId = Base.toUtf8HexString(sourceName);
//         string memory requestBody = prepareRequestBody(
//             minimalBlockNumber,
//             deadlineBlockNumber,
//             deadlineTimestamp,
//             destinationAddressHash,
//             amount,
//             standardPaymentReference,
//             checkSourceAddresses,
//             sourceAddressesRoot
//         );

//         (string[] memory headers, string memory body) = Base
//             .prepareAttestationRequest(attestationType, sourceId, requestBody);

//         // TODO change key in .env
//         // string memory baseUrl = "https://testnet-verifier-fdc-test.aflabs.org/";
//         string memory baseUrl = "https://fdc-verifiers-testnet.flare.network/";
//         string memory url = string.concat(
//             baseUrl,
//             "verifier/",
//             baseSourceName,
//             "/",
//             attestationTypeName,
//             "/prepareRequest"
//         );
//         console.log("url: %s", url);

//         // Posting the attestation request
//         (, bytes memory data) = url.post(headers, body);

//         Base.AttestationResponse memory response = Base.parseAttestationRequest(
//             data
//         );

//         // Writing to a file
//         Base.writeToFile(
//             dirPath,
//             attestationTypeName,
//             StringsBase.toHexString(response.abiEncodedRequest),
//             true
//         );
//     }
// }

// // Run with command
// //      forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:SubmitAttestationRequest --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

// contract SubmitAttestationRequest is Script {
//     using Surl for *;
//     // TODO add to docs that testnets are connected to testnets, and mainnets are connected to mainnets

//     function run() external {
//         // Reading the abiEncodedRequest from a file
//         string memory fileName = string.concat(attestationTypeName, ".txt");
//         string memory filePath = string.concat(dirPath, fileName);
//         string memory requestStr = vm.readLine(filePath);
//         bytes memory request = vm.parseBytes(requestStr);

//         // Submitting the attestation request
//         Base.submitAttestationRequest(request);

//         // Writing to a file
//         uint32 votingRoundId = Base.calculateRoundId();
//         string memory printString = string.concat(
//             requestStr,
//             "\n",
//             Strings.toString(votingRoundId)
//         );
//         Base.writeToFile(dirPath, attestationTypeName, printString, true);
//     }
// }

// // Run with command
// //      forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:RetrieveDataAndProof --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

// contract RetrieveDataAndProof is Script {
//     using Surl for *;

//     function run() external {
//         string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL"); // XXX
//         string memory apiKey = vm.envString("X_API_KEY");
//         string memory fileName = string.concat(attestationTypeName, ".txt");
//         string memory filePath = string.concat(dirPath, fileName);

//         // We import the roundId and abiEncodedRequest from the first file
//         string memory requestBytes = vm.readLine(filePath);
//         string memory votingRoundId = vm.readLine(filePath);

//         console.log("votingRoundId: %s\n", votingRoundId);
//         console.log("requestBytes: %s\n", requestBytes);

//         // Preparing the proof request
//         string[] memory headers = Base.prepareHeaders(apiKey);
//         string memory body = string.concat(
//             '{"votingRoundId":',
//             votingRoundId,
//             ',"requestBytes":"',
//             requestBytes,
//             '"}'
//         );
//         console.log("body: %s\n", body);
//         console.log(
//             "headers: %s",
//             string.concat("{", headers[0], ", ", headers[1]),
//             "}\n"
//         );

//         // Posting the proof request
//         string memory url = string.concat(
//             daLayerUrl,
//             // "api/v0/fdc/get-proof-round-id-bytes"
//             "api/v1/fdc/proof-by-request-round-raw"
//         );
//         console.log("url: %s\n", url);

//         (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

//         // Decoding the response from JSON data
//         bytes memory dataJson = Base.parseData(data);
//         Base.ParsableProof memory proof = abi.decode(
//             dataJson,
//             (Base.ParsableProof)
//         );

//         IReferencedPaymentNonexistence.Response memory proofResponse = abi
//             .decode(
//                 proof.responseHex,
//                 (IReferencedPaymentNonexistence.Response)
//             );

//         // Verifying the proof
//         IReferencedPaymentNonexistence.Proof
//             memory _proof = IReferencedPaymentNonexistence.Proof(
//                 proof.proofs,
//                 proofResponse
//             );
//         verifyProof(_proof);
//     }

//     function verifyProof(
//         IReferencedPaymentNonexistence.Proof memory proof
//     ) public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         bool isValid = ContractRegistry
//             .getFdcVerification()
//             .verifyReferencedPaymentNonexistence(proof);
//         console.log("proof is valid: %s\n", StringsBase.toString(isValid));

//         vm.stopBroadcast();
//     }
// }

// // forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:Deploy --private-key $PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi

// contract Deploy is Script {
//     function run() external {}
// }

// //
// //
// //
// // TODO

// string constant attestationTypeName = "ReferencedPaymentNonexistence";
// string constant dirPath = "data/";

// // Run with command
// //      forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:PostRequest --private-key $PRIVATE_KEY --rpc-url $COSTON_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast  --ffi

// contract PostRequest is Script {
//     using Surl for *;
//     // TODO add to docs that testnets are connected to testnets, and mainnets are connected to mainnets

//     function run() external {
//         // Setting parameters
//         string memory sourceId = Base.toUtf8HexString("testBTC"); // Bitcoin chain ID
//         string memory baseSourceName = "btc";

//         // Setting request data
//         string memory minimalBlockNumber = "TODO";
//         string memory deadlineBlockNumber = "TODO";
//         string memory deadlineTimestamp = "TODO";
//         string memory destinationAddressHash = "TODO";
//         string memory amount = "TODO";
//         string memory standardPaymentReference = "TODO";
//         string memory checkSourceAddresses = "TODO";
//         string memory sourceAddressesRoot = "TODO";
//         // Preparing the attestation request
//         string memory attestationType = Base.toUtf8HexString(
//             attestationTypeName
//         );
//         string memory baseUrl = "https://fdc-verifiers-testnet.flare.network/";
//         string memory url = string.concat(
//             baseUrl,
//             "verifier/",
//             baseSourceName,
//             "/",
//             attestationTypeName,
//             "/prepareRequest"
//         );
//         console.log("url: %s", url);
//         string memory requestBody = string.concat(
//             '{"minimalBlockNumber": "',
//             minimalBlockNumber,
//             '","deadlineBlockNumber": "',
//             deadlineBlockNumber,
//             '","deadlineTimestamp": "',
//             deadlineTimestamp,
//             '","destinationAddressHash": "',
//             destinationAddressHash,
//             '","amount": "',
//             amount,
//             '","standardPaymentReference": "',
//             standardPaymentReference,
//             '","checkSourceAddresses": "',
//             checkSourceAddresses,
//             '","sourceAddressesRoot": "',
//             sourceAddressesRoot,
//             '"}'
//         );

//         (string[] memory headers, string memory body) = Base
//             .prepareAttestationRequest(attestationType, sourceId, requestBody);

//         // Posting the attestation request
//         (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

//         Base.AttestationResponse memory response = Base.parseAttestationRequest(
//             data
//         );

//         // Submitting the attestation request
//         Base.submitAttestationRequest(response);

//         // Writing to a file
//         uint32 votingRoundId = Base.calculateRoundId();
//         string memory requestBytes = StringsBase.toHexString(
//             response.abiEncodedRequest
//         );
//         string memory printString = string.concat(
//             Strings.toString(votingRoundId),
//             "\n",
//             requestBytes
//         );
//         Base.writeToFile(dirPath, attestationTypeName, printString, true);
//     }
// }

// // Run with command
// //      forge script script/fdcExample/ReferencedPaymentNonexistence.s.sol:RetrieveData --private-key $PRIVATE_KEY --rpc-url $COSTON_RPC_URL --etherscan-api-key $FLARE_API_KEY --broadcast --ffi
// contract RetrieveData is Script {
//     using Surl for *;

//     function run() external {
//         string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL"); // XXX
//         string memory apiKey = vm.envString("X_API_KEY");
//         string memory fileName = string.concat(attestationTypeName, ".txt");
//         string memory filePath = string.concat(dirPath, fileName);

//         // We import the roundId and abiEncodedRequest from the first file
//         string memory votingRoundId = vm.readLine(filePath);
//         string memory requestBytes = vm.readLine(filePath);

//         uint256 roundId = Base.stringToUint(votingRoundId);
//         console.log("votingRoundId: %s\n", Strings.toString(roundId));
//         console.log("requestBytes: %s\n", requestBytes);

//         // Preparing the proof request
//         string memory url = string.concat(
//             daLayerUrl,
//             "api/v0/fdc/get-proof-round-id-bytes"
//         );
//         string[] memory headers = Base.prepareHeaders(apiKey);
//         string memory body = string.concat(
//             '{"votingRoundId":',
//             Strings.toString(roundId),
//             ',"requestBytes":"',
//             requestBytes,
//             '"}'
//         );
//         console.log("url: %s\n", url);
//         console.log(
//             "headers: %s",
//             string.concat("{", headers[0], ", ", headers[1]),
//             "\n}"
//         );
//         console.log("body: %s\n", body);

//         // Posting the proof request
//         (, bytes memory data) = Base.postAttestationRequest(url, headers, body);

//         // Decoding the response from JSON data
//         bytes memory dataJson = Base.parseData(data);
//         ParsableProof memory proofResponse = abi.decode(
//             dataJson,
//             (ParsableProof)
//         );

//         IReferencedPaymentNonexistence.Proof memory proof = recastProof(
//             proofResponse
//         );
//         console.log("json: %s\n", FdcStrings.toJsonString(proof));

//         // Using the data

//         // useData(proofResponse);
//     }

//     // function useData(ParsableProof memory proofResponse) public {
//     //     uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//     //     vm.startBroadcast(deployerPrivateKey);

//     //     TransferEventListener listener = new TransferEventListener();
//     //     IEVMTransaction.Proof memory proof = recastProof(proofResponse);
//     //     string memory a = FdcStrings.toJsonString(proof);
//     //     console.log("json: %s\n", a);

//     //     // FIXME

//     //     listener.collectTransferEvents(proof);

//     //     TokenTransfer[] memory tokenTransfers = listener.getTokenTransfers();

//     //     for (uint256 i = 0; i < tokenTransfers.length; i++) {
//     //         console.log(
//     //             "\nToken transfer: %s, %s, %s",
//     //             tokenTransfers[i].from,
//     //             tokenTransfers[i].to,
//     //             tokenTransfers[i].value
//     //         );
//     //     }
//     //     vm.stopBroadcast();
//     // }
// }

// // HACK because of how parseJson recognises types, we need the following intermidiate structs
// // and a function to recast them as IEVMTransaction.Proof

// // TODO DA layer returns "proof", IReferencedPaymentNonexistence has a field named merkleProof: same for "response" and "data"

// struct ParsableProof {
//     bytes32[] proof;
//     ParsableResponse response;
// }

// struct ParsableResponse {
//     bytes32 attestationType;
//     string lowestUsedTimestamp;
//     ParsableRequestBody requestBody;
//     ParsableResponseBody responseBody;
//     bytes32 sourceId;
//     string votingRound;
// }
// struct ParsableRequestBody {
//     uint256 amount;
//     bool checkSourceAddresses;
//     uint256 deadlineBlockNumber;
//     uint256 deadlineTimestamp;
//     bytes32 destinationAddressHash;
//     uint256 minimalBlockNumber;
//     bytes32 sourceAddressesRoot;
//     bytes32 standardPaymentReference;
// }
// struct ParsableResponseBody {
//     uint256 firstOverflowBlockNumber;
//     uint256 firstOverflowBlockTimestamp;
//     uint256 minimalBlockTimestamp;
// }

// function recastProof(
//     ParsableProof memory parsableProof
// ) pure returns (IReferencedPaymentNonexistence.Proof memory) {
//     bytes32[] memory merkleProof = parsableProof.proof;
//     IReferencedPaymentNonexistence.RequestBody
//         memory requestBody = IReferencedPaymentNonexistence.RequestBody(
//             uint64(parsableProof.response.requestBody.minimalBlockNumber),
//             uint64(parsableProof.response.requestBody.deadlineBlockNumber),
//             uint64(parsableProof.response.requestBody.deadlineTimestamp),
//             parsableProof.response.requestBody.destinationAddressHash,
//             parsableProof.response.requestBody.amount,
//             parsableProof.response.requestBody.standardPaymentReference,
//             parsableProof.response.requestBody.checkSourceAddresses,
//             parsableProof.response.requestBody.sourceAddressesRoot
//         );

//     IReferencedPaymentNonexistence.ResponseBody
//         memory responseBody = IReferencedPaymentNonexistence.ResponseBody(
//             uint64(parsableProof.response.responseBody.minimalBlockTimestamp),
//             uint64(
//                 parsableProof.response.responseBody.firstOverflowBlockNumber
//             ),
//             uint64(
//                 parsableProof.response.responseBody.firstOverflowBlockTimestamp
//             )
//         );

//     IReferencedPaymentNonexistence.Response
//         memory data = IReferencedPaymentNonexistence.Response(
//             parsableProof.response.attestationType,
//             parsableProof.response.sourceId,
//             uint64(Base.stringToUint(parsableProof.response.votingRound)),
//             uint64(
//                 Base.stringToUint(parsableProof.response.lowestUsedTimestamp)
//             ),
//             requestBody,
//             responseBody
//         );
//     IReferencedPaymentNonexistence.Proof
//         memory proof = IReferencedPaymentNonexistence.Proof(merkleProof, data);
//     return proof;
// }
