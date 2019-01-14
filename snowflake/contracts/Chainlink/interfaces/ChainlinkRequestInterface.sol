pragma solidity 0.5.0;

interface ChainlinkRequestInterface {
  function cancel(bytes32 requestId) external;
  function requestData(
    address sender,
    uint256 amount,
    uint256 version,
    bytes32 id,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 nonce,
    bytes calldata data
  ) external;
}