pragma solidity ^0.5.0;

import "./interfaces/ProtectedWalletFactoryInterface.sol";
import "./interfaces/SnowflakeInterface.sol";
import "./interfaces/ClientRaindropInterface.sol";
import "./interfaces/IdentityRegistryInterface.sol";
import "./SnowflakeResolver.sol";
import "./interfaces/HydroInterface.sol";
import "./zeppelin/math/SafeMath.sol";
import "./Chainlink/Chainlinked.sol";

/**
 * Protected wallet Implementation
 * 1. Enable withdrawals up to a predetermined threshold specified in 
 * the contract constructor
 * 2. Enable withdrawals greater than predetermined threshold after
 * going through Chainlinked 2FA process with external -hydroId?- (non-associated)
 * address
 * 3. Enable one time password permissioned function that a. deposits
 * sends the remaining contract funds to the calling address and b. 
 * deletes the permissioned wallet and modifies factory contract state
 * accordingly.
 * 4. Allow for 2FA permissioned adjustments to daily limit (Standard
 * daily limit is 10 hydro tokens)
 */

contract ProtectedWallet is SnowflakeResolver, Chainlinked {
    using SafeMath for uint;

    uint private    ein;
    string private  hydroId;
    address private hydroIdAddr;
    uint private    dailyLimit;
    uint private    hydroBalance;
    bool private    hasPassword;
    bool private    resolverAdded;
    uint private    withdrawnToday;
    uint private    timestamp;
    
    bytes32 private                   oneTimePass;
    mapping (bytes32 => bool) private passHashCommit;

    ProtectedWalletFactoryInterface factoryContract;
    IdentityRegistryInterface       idRegistry;
    ClientRaindropInterface         clientRaindrop;
    SnowflakeInterface              snowflake;
    HydroInterface                  hydro;

    event CommitHash(address indexed _from, bytes32 indexed _hash);
    event DepositFromSnowflake(uint indexed _ein, uint indexed _amount, address _from);
    event DepositFromAddress(uint indexed _amount, address indexed _from);
    event WithdrawToSnowflake(uint indexed _ein, uint indexed _amount);
    event WithdrawToAddress(address indexed _to, uint indexed _amount);

    //Chainlink constants

    bytes32 constant GET_BYTES32_JOB = bytes32("ccc41cccdce8492398ac2d5558debf55");
    bytes32 constant POST_BYTES32_JOB = bytes32("954572881f024f89bc230e572dc5d8ea");
    bytes32 constant INT256_JOB = bytes32("796add02d7b44142b42e675e21ab0ad0");
    bytes32 constant INT256_MUL_JOB = bytes32("913f3f4e8aca42498d6741dfe9cb8cf2");
    bytes32 constant UINT256_JOB = bytes32("82d69822e1094857b8416053d0b032bb");
    bytes32 constant UINT256_MUL_JOB = bytes32("73fda4e2b40d48f3b22d4f839cd5691b");
    bytes32 constant HYDRO_JOB = bytes32("278c97ffadb54a5bbb93cfec5f7b5503");

    // Constructor Logic

    constructor(uint _ein, uint _dailyLimit, address snowflakeAddress, bytes32 passHash, address clientRaindropAddr) 
    public 
    SnowflakeResolver("Your personal protected wallet", "Protect your funds without locking them up in cold storage", snowflakeAddress, true, true) 
    {
        setLinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setOracle(0xa8DC9e5D99DF8790D700C885e5124573fA1720a3);
        ein = _ein;
        dailyLimit = _dailyLimit;
        clientRaindrop = ClientRaindropInterface(clientRaindropAddr);
        (hydroIdAddr, hydroId) = clientRaindrop.getDetails(ein);
        resolverAdded = false;
        timestamp = now;
        oneTimePass = keccak256(abi.encodePacked(address(this), passHash));
        if (passHash == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000000000000) {
            hasPassword = false;
            delete oneTimePass;
        }
        else {
            hasPassword = true;
        }
        factoryContract = ProtectedWalletFactoryInterface(msg.sender);
        setSnowflakeAddress(address(factoryContract.getSnowflakeAddress()));
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);
        snowflake = SnowflakeInterface(snowflakeAddress);
        idRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
        hydro = HydroInterface(snowflake.hydroTokenAddress());
    }

    modifier senderIsFactory() {
        require(msg.sender == address(factoryContract));
        _; 
    }

    modifier walletHasPassword() {
        require(hasPassword == true);
        _;
    }

    // Getters

    function getDailyLimit() public view returns (uint) {
        return dailyLimit;
    }

    function getHydroBalance() public view returns (uint) {
        return hydroBalance;
    }

    function checkIfCommitExists(bytes32 commit) public view returns (bool) {
        return passHashCommit[commit];
    }

    function getEIN() public view returns (uint) {
        return ein;
    }

    function getHydroId() public view returns (string memory) {
        return hydroId;
    }

    function getBalance() public view returns (uint) {
        return hydro.balances(address(this));
    }

    function getWithdrawnToday() public view returns (uint) {
        return withdrawnToday;
    }

    function getOneTimePassHash() public view returns (bytes32) {
        return oneTimePass;
    }

    function getHasPassword() public view returns (bool) {
        return hasPassword;
    }

    // Wallet Logic

    function receiveApproval(address sender, uint value, address _tokenAddress, bytes memory) public {
        require(msg.sender == _tokenAddress, "Malformed inputs");
        require(_tokenAddress == address(hydro), "Token address is not the HYDRO token contract");
        depositFromAddress(sender, value);
    }

    function depositFromAddress(address sender, uint value) internal {
        require(hydro.transferFrom(sender, address(this), value));
        hydroBalance = hydroBalance.add(value);
        emit DepositFromAddress(value, address(this));
    }

    function depositFromSnowflake(uint amount) public {
        uint ein = idRegistry.getEIN(msg.sender);
        hydroBalance = hydroBalance.add(amount);
        snowflake.withdrawSnowflakeBalanceFrom(ein, address(this), amount);
        emit DepositFromSnowflake(idRegistry.getEIN(msg.sender), amount, msg.sender);
    }

    function withdrawToAddress(uint amount) public  {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        require(amount <= dailyLimit, "Can only make withdrawals up to daily limit");
        if (now <= timestamp + 1 days) {
            hydroBalance = hydroBalance.sub(amount);
            withdrawHydroBalanceTo(msg.sender, amount);
            withdrawnToday = withdrawnToday.add(amount);
            emit WithdrawToAddress(msg.sender, amount);
        }
        else {
            timestamp = now;
            withdrawnToday = 0;
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            withdrawHydroBalanceTo(msg.sender, amount);
            emit WithdrawToAddress(msg.sender, amount);
        }
    }

    function withdrawToSnowflake(uint amount) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        require(amount <= dailyLimit, "Can only make withdrawals up to daily limit");
        if (now >= timestamp + 1 days) {
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            transferHydroBalanceTo(ein, amount);
            emit WithdrawToSnowflake(ein, amount);
        }
        else {
            timestamp = now;
            withdrawnToday = 0;
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            transferHydroBalanceTo(ein, amount);
            emit WithdrawToSnowflake(ein, amount);
        }
    }

    // Use chainlink2FA to adjust daily limit
    function requestChangeDailyLimit(string memory code) public {
        require(bytes(code).length == 6);
        ChainlinkLib.Run memory run = newRun(HYDRO_JOB, address(this), this.fulfillChangeDailyLimit.selector);
    }

    function requestRecoverWithChainlink() public {
        //TODO
    }
    
    function fulfillChangeDailyLimit(bytes32 _requestId, bool _response) 
        public checkChainlinkFulfillment(_requestId) 
    {  
        require(_response == true, "Could not fulfill change daily limit request");
    }

    function fulfillRecoverWithChainlink(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) 
    {
        require(_response == true, "Could not fulfill chainlink recovery request");
    }

    function() external payable {
        revert();
    }

    function revealAndRecover(bytes32 _hash, address payable _dest, string memory password) public {
        require(passHashCommit[_hash] == true, "Must provide commit hash before reveal phase");
        require(keccak256(abi.encodePacked(_dest, password)) == _hash, "Hashed input values not equal to commit hash");
        bytes32 passHash = keccak256(abi.encodePacked(password));
        require(keccak256(abi.encodePacked(address(this), passHash)) == oneTimePass, "Invalid password");
        withdrawHydroBalanceTo(_dest, hydroBalance);
        factoryContract.deleteWallet(ein);
        selfdestruct(_dest);
    }

    function onAddition(uint ein, uint, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        resolverAdded = true;
        return true;
    }

    function onRemoval(uint ein, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        return true;
    }

    function commitHash(bytes32 _hash) public walletHasPassword() {
        passHashCommit[_hash] = true;
        emit CommitHash(msg.sender, _hash);
    }
    
}