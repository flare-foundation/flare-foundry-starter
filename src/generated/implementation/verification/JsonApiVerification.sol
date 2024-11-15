// SPDX-License-Identifier: MIT
  pragma solidity 0.8.20;
  
  import '../../../interfaces/types/IJsonApi.sol';
  import '../../interfaces/verification/IJsonApiVerification.sol';
  
  /**
   * Contract mocking verifying JsonApi attestations.
   */
  contract JsonApiVerification is IJsonApiVerification {
  
     /**
      * @inheritdoc IJsonApiVerification
      */
     function verifyJsonApi(
        IJsonApi.Proof calldata _proof
     ) external pure returns (bool _proved) {
        return _proof.data.attestationType == bytes32("JsonApi");
     }
  }
     