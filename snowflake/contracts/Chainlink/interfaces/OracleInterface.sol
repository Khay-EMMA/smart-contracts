pragma solidity 0.5.0;

interface OracleInterface {
  function fulfillData(uint256 requestId, bytes32 data) external returns (bool);
  function getAuthorizationStatus(address node) external view returns (bool);
  function setFulfillmentPermission(address node, bool allowed) external;
  function withdraw(address recipient, uint256 amount) external;
  function withdrawable() external view returns (uint256);
}
