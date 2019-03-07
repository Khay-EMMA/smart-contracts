pragma solidity ^0.5.0;

import "./interfaces/ProtectedWalletFactoryInterface.sol";
import "./interfaces/SnowflakeInterface.sol";
import "./interfaces/ClientRaindropInterface.sol";
import "./interfaces/IdentityRegistryInterface.sol";
import "./Chainlink/interfaces/LinkTokenInterface.sol";
import "./SnowflakeResolver.sol";
import "./interfaces/HydroInterface.sol";
import "./zeppelin/math/SafeMath.sol";
import "./Chainlink/Chainlinked.sol";
//import "./interfaces/SnowflakeViaInterface.sol";


contract ProtectedWallet is SnowflakeResolver, Chainlinked {
    using SafeMath for uint;
    
    // Persistent state variables
    uint private    ein;
    string private  hydroId;
    address private hydroIdAddr;
    
    // Chainlink 2FA state variables
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
    
    bytes32 private                      oneTimePass;
    mapping (bytes32 => bool) private    passHashCommit;
    mapping (address => bytes32) private commitHashFrom;

    ProtectedWalletFactoryInterface factoryContract;
    IdentityRegistryInterface       idRegistry;
    ClientRaindropInterface         clientRaindrop;
    SnowflakeInterface              snowflake;
    HydroInterface                  hydro;
    LinkTokenInterface              linkContract;
    //SnowflakeViaInterface           uniswapVia;

    event CommitHash(address indexed _from, bytes32 indexed _hash);
    event DepositFromSnowflake(uint indexed _ein, uint indexed _amount, address _from);
    event DepositFromAddress(uint indexed _amount, address indexed _from);
    event WithdrawToSnowflake(uint indexed _ein, uint indexed _amount);
    event WithdrawToAddress(address indexed _to, uint indexed _amount);
    event RaindropMessage(uint indexed shortMessage);
    event ChainlinkCallback(bytes32 indexed requestId);

    // Chainlink job identifiers
    bytes32 LIMIT_JOB =                bytes32("f26b8184a106449c9a81ccdae1ef0b5c");
    bytes32 RECOVER_JOB =              bytes32("f26b8184a106449c9a81ccdae1ef0b5c");
    bytes32 ONETIME_TRANSFEREXT_JOB =  bytes32("f26b8184a106449c9a81ccdae1ef0b5c");
    bytes32 ONETIME_WITHDRAWEXT_JOB =  bytes32("f26b8184a106449c9a81ccdae1ef0b5c");
    bytes32 HYDRO_ID_JOB =             bytes32("bb00038cd23643eba3008d850b5ca8ba");

    constructor(uint _ein, uint _dailyLimit, address snowflakeAddress, address clientRaindropAddr) 
    public 
    SnowflakeResolver("Your personal protected wallet", "Protect your funds without locking them up in cold storage", snowflakeAddress, true, true) 
    {
        setLinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setOracle(0xA5e4D80F7FB2cd2dB23DB79A7337f223C67DaD22);
        linkContract = LinkTokenInterface(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        ein = _ein;
        dailyLimit = _dailyLimit;
        clientRaindrop = ClientRaindropInterface(clientRaindropAddr);
        //(hydroIdAddr, hydroId) = clientRaindrop.getDetails(ein);
        hydroId = "drlj97w";
        resolverAdded = false;
        timestamp = now;
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
    //Returns the contract daily withdrawal limit
    function getDailyLimit() public view returns (uint) {
        return dailyLimit;
    }

    // Returns the current balance in link tokens
    function getLinkBalance() public returns (uint) {
        return linkContract.balanceOf(address(this));
    }

    // Returns whether or not a password recovery commit has been pushed
    function checkIfCommitExists(bytes32 commit) public view returns (bool) {
        return passHashCommit[commit];
    }

    // Returns the EIN associated with this contract
    function getEIN() public view returns (uint) {
        return ein;
    }

    // Returns the hydroId used for chainlinked 2FA and recovery
    function getHydroId() public view returns (string memory) {
        return hydroId;
    }

    // Returns the current balance of the contract in hydro tokens
    function getBalance() public view returns (uint) {
        return hydro.balances(address(this));
    }

    // Returns the amount of tokens withdrawn within the last 24 hour period
    function getWithdrawnToday() public view returns (uint) {
        return withdrawnToday;
    }

    // Returns the commit hash
    function getCommitHash(address from) public view returns (bytes32) {
        return commitHashFrom[from];
    } 

    // 
    function getOneTimePassHash() public view returns (bytes32) {
        return oneTimePass;
    }

    function getHasPassword() public view returns (bool) {
        return hasPassword;
    }

    function setJobIds(bytes16[5] memory ids) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        LIMIT_JOB               = bytes32(ids[0]);
        RECOVER_JOB             = bytes32(ids[1]);
        ONETIME_TRANSFEREXT_JOB = bytes32(ids[2]);
        ONETIME_WITHDRAWEXT_JOB = bytes32(ids[3]);
        HYDRO_ID_JOB            = bytes32(ids[4]);
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
        ChainlinkLib.Run memory run = newRun(LIMIT_JOB, address(this), this.fulfillChangeDailyLimit.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        chainlinkRequest(run, 1 ether);
        emit RaindropMessage(shortMessage);
        pendingDailyLimit = newDailyLimit;
    }

    // request to run the one time chainlinked recovery
    function requestChainlinkRecover() public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(pendingRecovery == false, "Recovery request already in progress");
        ChainlinkLib.Run memory run = newRun(RECOVER_JOB, address(this), this.fulfillChainlinkRecover.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        emit RaindropMessage(shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    // Request to transfer hydro above daily limit to an external address
    function requestOneTimeTransferExternal(uint amount, address _to, uint numHydro, uint minEthBought) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(oneTimeTransferExtAmount == 0, "A transfer request is already in progress");
        require(oneTimeTransferExtAddress == address(0), "Transfer address must be reset");
        oneTimeTransferExtAmount = amount;
        oneTimeTransferExtAddress = _to;
        ChainlinkLib.Run memory run = newRun(ONETIME_TRANSFEREXT_JOB, address(this), this.fulfillOneTimeTransferExternal.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        emit RaindropMessage(shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    // Request to withdraw hydro above daily limit to an external ein
    function requestOneTimeWithdrawalExternal(uint amount, uint einTo) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only addresses associated with this wallet ein can invoke this function");
        require(oneTimeWithdrawalExtAmount == 0, "Withdrawal to external ein already initiated");
        require(oneTimeWithdrawalExtEin == 0, "Withdrawal to external ein already initiated");
        oneTimeWithdrawalExtAmount = amount;
        oneTimeWithdrawalExtEin = einTo;
        ChainlinkLib.Run memory run = newRun(ONETIME_WITHDRAWEXT_JOB, address(this), this.fulfillOneTimeWithdrawalExternal.selector);
        run.add("role", "client");
        run.add("hydroid", hydroId);
        uint longMessage = uint(blockhash(block.number - 1));
        uint shortMessage = longMessage % 1000000;
        run.addUint("message", shortMessage);
        emit RaindropMessage(shortMessage);
        chainlinkRequest(run, 1 ether);
    }

    function fulfillChangeDailyLimit(bytes32 _requestId, bool _response) 
        public checkChainlinkFulfillment(_requestId) returns (bool) 
    {  
        if (_response == true) {
            dailyLimit = pendingDailyLimit;
            pendingDailyLimit = 0;
            emit ChainlinkCallback(_requestId);
            return true;
        } else {
            pendingDailyLimit = 0;
            emit ChainlinkCallback(_requestId);
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
            emit ChainlinkCallback(_requestId);
            selfdestruct(hydroAddr);
        } else {
            emit ChainlinkCallback(_requestId);
            return false;
        }
    }

    function fulfillOneTimeTransferExternal(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) returns (bool)
    {
        if (_response == true) {
            withdrawHydroBalanceTo(oneTimeTransferExtAddress, oneTimeTransferExtAmount);
            hydroBalance = hydroBalance.sub(oneTimeTransferExtAmount);
            oneTimeTransferExtAddress = address(0);
            oneTimeTransferExtAmount = 0;
            emit ChainlinkCallback(_requestId);
            return true;
        } else {
            oneTimeTransferExtAddress = address(0);
            oneTimeTransferExtAmount = 0;
            emit ChainlinkCallback(_requestId);
            return false;
        }
    }

    function fulfillOneTimeWithdrawalExternal(bytes32 _requestId, bool _response)
        public checkChainlinkFulfillment(_requestId) returns (bool)
    {
        if (_response == true) {
            transferHydroBalanceTo(oneTimeWithdrawalExtEin, oneTimeWithdrawalExtAmount);
            hydroBalance = hydroBalance.sub(oneTimeWithdrawalExtAmount);
            oneTimeWithdrawalExtEin = 0;
            oneTimeWithdrawalExtAmount = 0;
            emit ChainlinkCallback(_requestId);
            return true;
        } else {
            oneTimeWithdrawalExtEin = 0;
            oneTimeWithdrawalExtAmount = 0;
            emit ChainlinkCallback(_requestId);
            return false;
        }
    }


    function resetChainlinkState() public returns (bool) {
        pendingRecovery = false;
        pendingDailyLimit = 0;
        oneTimeWithdrawalAmount = 0;
        oneTimeTransferExtAmount = 0;
        oneTimeTransferExtAddress = address(0);
        oneTimeWithdrawalExtAmount = 0;
        oneTimeWithdrawalExtEin = 0;
    }

    function revealAndRecover(bytes32 _hash, address payable _dest, string memory password) public {
        require(keccak256(abi.encodePacked(address(uint160(_dest)), password)) == _hash, "Hashed input values not equal to commit hash");
        bytes32 passHash = keccak256(abi.encodePacked(password));
        require(keccak256(abi.encodePacked(address(this), passHash)) == oneTimePass, "Invalid password");
        withdrawHydroBalanceTo(_dest, hydroBalance);
        factoryContract.deleteWallet(ein);
        selfdestruct(_dest);
    }

    function onAddition(uint ein, uint, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        ChainlinkLib.Run memory run = newRun(HYDRO_ID_JOB, address(this), this.fulfillOnAddition.selector);
        run.add("role", "register");
        run.add("hydroId", hydroId);
        resolverAdded = true;
        chainlinkRequest(run, 1 ether);
        if (extraData.length == 32) {
            oneTimePass = keccak256(abi.encodePacked(address(this), extraData));
            hasPassword = true;
            resolverAdded = true;
        } 
        return true;
    }

    function fulfillOnAddition(bytes32 _requestId, bool _response) 
        public checkChainlinkFulfillment(_requestId) returns (bool) {
            return true;
    }

    function onRemoval(uint ein, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        return true;
    }

    function commitHash(bytes32 _hash) public walletHasPassword() {
        passHashCommit[_hash] = true;
        commitHashFrom[msg.sender] = _hash;
        emit CommitHash(msg.sender, _hash);
    }
    
}
