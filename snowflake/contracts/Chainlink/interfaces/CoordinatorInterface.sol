pragma solidity 0.5.0;

interface CoordinatorInterface {
  function initiateServiceAgreement(
    uint256 payment,
    uint256 expiration,
    uint256 endAt,
    address[] calldata oracles,
    uint8[] calldata vs,
    bytes32[] calldata rs,
    bytes32[] calldata ss,
    bytes32 requestDigest
  ) external returns (bytes32);
  function fulfillData(uint256 requestId, bytes32 data) external returns (bool);
}
