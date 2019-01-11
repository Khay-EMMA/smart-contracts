pragma solidity ^0.5.0;

interface ProtectedWalletFactoryInterface {
    function deleteWallet(uint ein) external returns (bool);
    function getEinToWallet(uint ein) external returns (address);
    function getEinHasWallet(uint ein) external returns (bool);
    function getSnowflakeAddress() external returns (address);
}