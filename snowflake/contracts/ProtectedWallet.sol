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
    
    // Persistent state variables
    uint private    ein;
    string private  hydroId;
    address private hydroIdAddr;
    
    // Chainlink 2FA state variables
    uint private    timeOfLast2FA;
    bool private    pendingRecovery;
    uint private    pendingDailyLimit;
    uint private    oneTimeWithdrawalAmount;
    uint private    oneTimeTransferExtAmount;
    address private oneTimeTransferExtAddress;
    uint private    oneTimeWithdrawalExtAmount;
    uint private    oneTimeWithdrawalExtEin;

    uint private    hydroBalance;
    bool private    hasPassword;
    bool private    resolverAdded;
    uint private    withdrawnToday;
    uint private    timestamp;
    uint private    dailyLimit;
    
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

    // Chainlink job identifiers
    bytes32 constant LIMIT_JOB =                bytes32("d53bdaec52e4436e9e730acf8b64703d");
    bytes32 constant RECOVER_JOB =              bytes32("bd09b003710a494a855d233c30837345");
    bytes32 constant ONETIME_WITHDRAW_JOB =     bytes32("7d01cb0e33044d3695d1734032d970e2");
    bytes32 constant ONETIME_TRANSFEREXT_JOB =  bytes32("e24d7b3b279046a7b310579703918f58");
    bytes32 constant ONETIME_WITHDRAWEXT_JOB =  bytes32("73ae93813c174b4a8db3068096f5d23a");

    constructor(uint _ein, uint _dailyLimit, address snowflakeAddress, bytes32 passHash, address clientRaindropAddr) 
    public 
    SnowflakeResolver("Your personal protected wallet", "Protect your funds without locking them up in cold storage", snowflakeAddress, true, true) 
    {
        setLinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setOracle(0xA5e4D80F7FB2cd2dB23DB79A7337f223C67DaD22);
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
        uint _ein = idRegistry.getEIN(msg.sender);
        hydroBalance = hydroBalance.add(amount);
        snowflake.withdrawSnowflakeBalanceFrom(_ein, address(this), amount);
        emit DepositFromSnowflake(idRegistry.getEIN(msg.sender), amount, msg.sender);
    }

    function withdrawToAddress(uint amount, address addr) public  {
        require(amount <= dailyLimit, "Can only make withdrawals up to daily limit");
        if (now <= timestamp + 1 days) {
            hydroBalance = hydroBalance.sub(amount);
            withdrawHydroBalanceTo(addr, amount);
            withdrawnToday = withdrawnToday.add(amount);
            emit WithdrawToAddress(addr, amount);
        }
        else {
            timestamp = now;
            withdrawnToday = 0;
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            withdrawHydroBalanceTo(addr, amount);
            emit WithdrawToAddress(addr, amount);
        }
    }

    function withdrawToSnowflake(uint amount, uint _einTo) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        require(amount <= dailyLimit, "Can only make withdrawals up to daily limit");
        if (now >= timestamp + 1 days) {
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            transferHydroBalanceTo(_einTo, amount);
            emit WithdrawToSnowflake(_einTo, amount);
        }
        else {
            timestamp = now;
            withdrawnToday = 0;
            hydroBalance = hydroBalance.sub(amount);
            withdrawnToday = withdrawnToday.add(amount);
            transferHydroBalanceTo(_einTo, amount);
            emit WithdrawToSnowflake(_einTo, amount);
        }
    }

    // Request to adjust daily limit
    function requestChangeDailyLimit(uint newDailyLimit) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        require(pendingDailyLimit == 0, "A change daily limit request is already in progress");
        timeOfLast2FA = now;
        ChainlinkLib.Run memory run = newRun(LIMIT_JOB, address(this), this.fulfillChangeDailyLimit.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
        pendingDailyLimit = newDailyLimit;
    }

    // request to run the one time chainlinked recovery
    function requestChainlinkRecover() public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(pendingRecovery == false, "Recovery request already in progress");
        timeOfLast2FA = now;
        ChainlinkLib.Run memory run = newRun(RECOVER_JOB, address(this), this.fulfillChainlinkRecover.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    // Request to withdraw hydro above daily limit to snowflake
    function requestOneTimeWithdrawal(uint amount) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(oneTimeWithdrawalAmount == 0, "A withdrawal request is already in progress");
        timeOfLast2FA = now;
        oneTimeWithdrawalAmount = amount;
        ChainlinkLib.Run memory run = newRun(ONETIME_WITHDRAW_JOB, address(this), this.fulfillOneTimeWithdrawal.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    // Request to transfer hydro above daily limit to an external address
    function requestOneTimeTransferExternal(uint amount, address _to) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(oneTimeTransferExtAmount == 0, "A transfer request is already in progress");
        require(oneTimeTransferExtAddress == address(0), "Transfer address must be reset");
        timeOfLast2FA = now;
        oneTimeTransferExtAmount = amount;
        oneTimeTransferExtAddress = _to;
        ChainlinkLib.Run memory run = newRun(ONETIME_TRANSFEREXT_JOB, address(this), this.fulfillOneTimeTransferExternal.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    // Request to withdraw hydro above daily limit to an external ein
    function requestOneTimeWithdrawalExternal(uint amount, uint einTo) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(oneTimeWithdrawalExtAmount == 0, "Withdrawal to external ein already initiated");
        require(oneTimeWithdrawalExtEin == 0, "Withdrawal to external ein already initiated");
        timeOfLast2FA = now;
        oneTimeWithdrawalExtAmount = amount;
        oneTimeWithdrawalExtEin = einTo;
        ChainlinkLib.Run memory run = newRun(ONETIME_WITHDRAWEXT_JOB, address(this), this.fulfillOneTimeWithdrawalExternal.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    function fulfillChangeDailyLimit(bytes32 _requestId, bool _response) 
        public checkChainlinkFulfillment(_requestId) returns (bool) 
    {  
        if (_response == true) {
            dailyLimit = pendingDailyLimit;
            pendingDailyLimit = 0;
            return true;
        } else {
            pendingDailyLimit = 0;
            return false;
        }
    }

    function fulfillChainlinkRecover(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) returns (bool)
    {
        if (_response == true) {
            uint amount = getBalance();
            withdrawHydroBalanceTo(hydroIdAddr, amount);
            factoryContract.deleteWallet(ein);
            address payable hydroAddr = address(uint160(hydroIdAddr));
            selfdestruct(hydroAddr);
        } else {
            return false;
        }
    }

    function fulfillOneTimeWithdrawal(bytes32 _requestId, bool _response) 
        public checkChainlinkFulfillment(_requestId) returns (bool) 
    {
        if (_response == true) {
            transferHydroBalanceTo(ein, oneTimeWithdrawalAmount);
            oneTimeWithdrawalAmount = 0;
            return true;
        } else {
            oneTimeWithdrawalAmount = 0;
            return false;
        }
    }

    function fulfillOneTimeTransferExternal(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) returns (bool)
    {
        if (_response == true) {
            withdrawHydroBalanceTo(oneTimeTransferExtAddress, oneTimeTransferExtAmount);
            oneTimeTransferExtAddress = address(0);
            oneTimeTransferExtAmount = 0;
            return true;
        } else {
            oneTimeTransferExtAddress = address(0);
            oneTimeTransferExtAmount = 0;
            return false;
        }
    }

    function fulfillOneTimeWithdrawalExternal(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) returns (bool)
    {
        if (_response == true) {
            transferHydroBalanceTo(oneTimeWithdrawalExtEin, oneTimeWithdrawalExtAmount);
            oneTimeWithdrawalExtEin = 0;
            oneTimeWithdrawalExtAmount = 0;
            return true;
        } else {
            oneTimeWithdrawalExtEin = 0;
            oneTimeWithdrawalExtAmount = 0;
            return false;
        }
    }

    function requestResetChainlinkState() public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the protected wallet associated ein can invoke this function");
        
    
    }

    function fulfillResetChainlinkState(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) 
    {
        pendingRecovery = false;
        pendingDailyLimit = 0;
        oneTimeWithdrawalAmount = 0;
        oneTimeTransferExtAmount = 0;
        oneTimeTransferExtAddress = address(0);
        oneTimeWithdrawalExtAmount = 0;
        oneTimeWithdrawalExtEin = 0;
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
