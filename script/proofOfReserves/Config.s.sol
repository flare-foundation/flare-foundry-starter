// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// This file holds the addresses and transaction hashes for the Proof of Reserves example.
// It must be manually updated after running the `Deploy` and `ActivateReaders` scripts.
library ProofOfReservesConfig {
    // TODO: STEP 1 - Update after running the Deploy script on Coston2
    address constant PROOF_OF_RESERVES_CONTRACT = 0x757DE2500ee4212d950c88758cD6dD5547F06F43;
    
    // TODO: STEP 1 - Update after running the Deploy script on Coston
    address constant TOKEN_COSTON = 0x381b0BA35229391e00bcab999E05412686FadFF0;
    address constant READER_COSTON = 0xc14879d523420090E450cCCc078fa3B1708f5F0B;

    // TODO: STEP 1 - Update after running the Deploy script on Coston2
    address constant TOKEN_COSTON2 = 0xD5D77C47A93C20A31Cd9948607335345f960aEcF;
    address constant READER_COSTON2 = 0x28344Fbee34Ff19949F2fAe79D79382440d5Ec1F;

    // TODO: STEP 2 - Update after running the ActivateReaders script on Coston & Coston2
    string constant TX_HASH_COSTON = "0xdf0c920109d54d3406692ed5449f363eee14c5951e54178423551c3ae16b86ca";
    string constant TX_HASH_COSTON2 = "0xa24323100bc3bc8318cd79ed0db779f024487229942956c08d82c90a9f9b1804";
}