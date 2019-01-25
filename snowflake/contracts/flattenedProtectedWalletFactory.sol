pragma solidity 0.5.0;

// File: contracts/zeppelin/math/SafeMath.sol

/**
* @title SafeMath
* @dev Math operations with safety checks that revert on error
*/
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

// File: contracts/zeppelin/ownership/Ownable.sol

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() public {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
    * @return the address of the owner.
    */
    function owner() public view returns(address) {
        return _owner;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
    * @return true if `msg.sender` is the owner of the contract.
    */
    function isOwner() public view returns(bool) {
        return msg.sender == _owner;
    }

    /**
    * @dev Allows the current owner to relinquish control of the contract.
    * @notice Renouncing to ownership will leave the contract without an owner.
    * It will not be possible to call the functions with the `onlyOwner`
    * modifier anymore.
    */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
    * @dev Transfers control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/interfaces/HydroInterface.sol

interface HydroInterface {
    function balances(address) external view returns (uint);
    function allowed(address, address) external view returns (uint);
    function transfer(address _to, uint256 _amount) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) external returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData)
        external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function totalSupply() external view returns (uint);

    function authenticate(uint _value, uint _challenge, uint _partnerId) external;
}

// File: contracts/interfaces/SnowflakeInterface.sol

interface SnowflakeInterface {
    function deposits(uint) external view returns (uint);
    function resolverAllowances(uint, address) external view returns (uint);

    function identityRegistryAddress() external returns (address);
    function hydroTokenAddress() external returns (address);
    function clientRaindropAddress() external returns (address);

    function setAddresses(address _identityRegistryAddress, address _hydroTokenAddress) external;
    function setClientRaindropAddress(address _clientRaindropAddress) external;

    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, string calldata casedHydroId,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function removeProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function upgradeProvidersFor(
        address approvingAddress, address[] calldata newProviders, address[] calldata oldProviders,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function addResolver(address resolver, bool isSnowflake, uint withdrawAllowance, bytes calldata extraData) external;
    function addResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, uint withdrawAllowance, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function changeResolverAllowances(address[] calldata resolvers, uint[] calldata withdrawAllowances) external;
    function changeResolverAllowancesDelegated(
        address approvingAddress, address[] calldata resolvers, uint[] calldata withdrawAllowances,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function removeResolver(address resolver, bool isSnowflake, bytes calldata extraData) external;
    function removeResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;

    function triggerRecoveryAddressChangeFor(
        address approvingAddress, address newRecoveryAddress, uint8 v, bytes32 r, bytes32 s
    ) external;

    function transferSnowflakeBalance(uint einTo, uint amount) external;
    function withdrawSnowflakeBalance(address to, uint amount) external;
    function transferSnowflakeBalanceFrom(uint einFrom, uint einTo, uint amount) external;
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) external;
    function transferSnowflakeBalanceFromVia(uint einFrom, address via, uint einTo, uint amount, bytes calldata _bytes)
        external;
    function withdrawSnowflakeBalanceFromVia(uint einFrom, address via, address to, uint amount, bytes calldata _bytes)
        external;
}

// File: contracts/interfaces/SnowflakeResolverInterface.sol

interface SnowflakeResolverInterface {
    function callOnAddition() external view returns (bool);
    function callOnRemoval() external view returns (bool);
    function onAddition(uint ein, uint allowance, bytes calldata extraData) external returns (bool);
    function onRemoval(uint ein, bytes calldata extraData) external returns (bool);
}

// File: contracts/SnowflakeResolver.sol

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;

    address public snowflakeAddress;

    bool public callOnAddition;
    bool public callOnRemoval;

    constructor(
        string memory _snowflakeName, string memory _snowflakeDescription,
        address _snowflakeAddress,
        bool _callOnAddition, bool _callOnRemoval
    )
        public
    {
        snowflakeName = _snowflakeName;
        snowflakeDescription = _snowflakeDescription;

        setSnowflakeAddress(_snowflakeAddress);

        callOnAddition = _callOnAddition;
        callOnRemoval = _callOnRemoval;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // this can be overriden to initialize other variables, such as e.g. an ERC20 object to wrap the HYDRO token
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    // if callOnAddition is true, onAddition is called every time a user adds the contract as a resolver
    // this implementation **must** use the senderIsSnowflake modifier
    // returning false will disallow users from adding the contract as a resolver
    function onAddition(uint ein, uint allowance, bytes memory extraData) public returns (bool);

    // if callOnRemoval is true, onRemoval is called every time a user removes the contract as a resolver
    // this function **must** use the senderIsSnowflake modifier
    // returning false soft prevents users from removing the contract as a resolver
    // however, note that they can force remove the resolver, bypassing onRemoval
    function onRemoval(uint ein, bytes memory extraData) public returns (bool);

    function transferHydroBalanceTo(uint einTo, uint amount) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(hydro.approveAndCall(snowflakeAddress, amount, abi.encode(einTo)), "Unsuccessful approveAndCall.");
    }

    function withdrawHydroBalanceTo(address to, uint amount) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(hydro.transfer(to, amount), "Unsuccessful transfer.");
    }

    function transferHydroBalanceToVia(address via, uint einTo, uint amount, bytes memory snowflakeCallBytes) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(
            hydro.approveAndCall(
                snowflakeAddress, amount, abi.encode(true, address(this), via, einTo, snowflakeCallBytes)
            ),
            "Unsuccessful approveAndCall."
        );
    }

    function withdrawHydroBalanceToVia(address via, address to, uint amount, bytes memory snowflakeCallBytes) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(
            hydro.approveAndCall(
                snowflakeAddress, amount, abi.encode(false, address(this), via, to, snowflakeCallBytes)
            ),
            "Unsuccessful approveAndCall."
        );
    }
}

// File: contracts/interfaces/IdentityRegistryInterface.sol

interface IdentityRegistryInterface {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        external pure returns (bool);

    // Identity View Functions /////////////////////////////////////////////////////////////////////////////////////////
    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAssociatedAddressFor(uint ein, address _address) external view returns (bool);
    function isProviderFor(uint ein, address provider) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function getIdentity(uint ein) external view returns (
        address recoveryAddress,
        address[] memory associatedAddresses, address[] memory providers, address[] memory resolvers
    );

    // Identity Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function createIdentity(address recoveryAddress, address[] calldata providers, address[] calldata resolvers)
        external returns (uint ein);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, address[] calldata resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAssociatedAddress(
        address approvingAddress, address addressToAdd, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function removeAssociatedAddress() external;
    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function addProviders(address[] calldata providers) external;
    function addProvidersFor(uint ein, address[] calldata providers) external;
    function removeProviders(address[] calldata providers) external;
    function removeProvidersFor(uint ein, address[] calldata providers) external;
    function addResolvers(address[] calldata resolvers) external;
    function addResolversFor(uint ein, address[] calldata resolvers) external;
    function removeResolvers(address[] calldata resolvers) external;
    function removeResolversFor(uint ein, address[] calldata resolvers) external;

    // Recovery Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function triggerRecoveryAddressChange(address newRecoveryAddress) external;
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function triggerDestruction(
        uint ein, address[] calldata firstChunk, address[] calldata lastChunk, bool resetResolvers
    ) external;
}

// File: contracts/interfaces/ClientRaindropInterface.sol

interface ClientRaindropInterface {
    function hydroStakeUser() external returns (uint);
    function hydroStakeDelegatedUser() external returns (uint);

    function setSnowflakeAddress(address _snowflakeAddress) external;
    function setStakes(uint _hydroStakeUser, uint _hydroStakeDelegatedUser) external;

    function signUp(address _address, string calldata casedHydroId) external;

    function hydroIDAvailable(string calldata uncasedHydroID) external view returns (bool available);
    function hydroIDDestroyed(string calldata uncasedHydroID) external view returns (bool destroyed);
    function hydroIDActive(string calldata uncasedHydroID) external view returns (bool active);

    function getDetails(string calldata uncasedHydroID) external view
        returns (uint ein, address _address, string memory casedHydroID);
    function getDetails(uint ein) external view returns (address _address, string memory casedHydroID);
    function getDetails(address _address) external view returns (uint ein, string memory casedHydroID);
}

// File: contracts/interfaces/ProtectedWalletFactoryInterface.sol

interface ProtectedWalletFactoryInterface {
    function deleteWallet(uint ein) external returns (bool);
    function getEinToWallet(uint ein) external returns (address);
    function getEinHasWallet(uint ein) external returns (bool);
    function getSnowflakeAddress() external returns (address);
}

// File: contracts/Chainlink/solidity-cborutils/Buffer.sol

library Buffer {
    struct buffer {
        bytes buf;
        uint capacity;
    }

    uint constant capacityMask = (2 ** 256) - 32; // ~0x1f

    function init(buffer memory buf, uint _capacity) internal pure {
        uint capacity = max(32, (_capacity + 0x1f) & capacityMask);
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            mstore(0x40, add(ptr, capacity))
        }
    }

    function resize(buffer memory buf, uint capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        append(buf, oldbuf);
    }

    function max(uint a, uint b) private pure returns(uint) {
        if(a > b) {
            return a;
        }
        return b;
    }

    /**
     * @dev Appends a byte array to the end of the buffer. Resizes if doing so
     * would exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer.
     */
    function append(buffer memory buf, bytes memory data) internal pure returns(buffer memory) {
        if(data.length + buf.buf.length > buf.capacity) {
            resize(buf, max(buf.capacity, data.length) * 2);
        }

        uint dest;
        uint src;
        uint len = data.length;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Start address = buffer address + buffer length + sizeof(buffer length)
            dest := add(add(bufptr, buflen), 32)
            // Update buffer length
            mstore(bufptr, add(buflen, mload(data)))
            src := add(data, 32)
        }

        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }

        return buf;
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     * exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer.
     */
    function append(buffer memory buf, uint8 data) internal pure {
        if(buf.buf.length + 1 > buf.capacity) {
            resize(buf, buf.capacity * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Address = buffer address + buffer length + sizeof(buffer length)
            let dest := add(add(bufptr, buflen), 32)
            mstore8(dest, data)
            // Update buffer length
            mstore(bufptr, add(buflen, 1))
        }
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     * exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer.
     */
    function appendInt(buffer memory buf, uint data, uint len) internal pure returns(buffer memory) {
        if(len + buf.buf.length > buf.capacity) {
            resize(buf, max(buf.capacity, len) * 2);
        }

        uint mask = 256 ** len - 1;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Address = buffer address + buffer length + len
            let dest := add(add(bufptr, buflen), len)
            mstore(dest, or(and(mload(dest), not(mask)), data))
            // Update buffer length
            mstore(bufptr, add(buflen, len))
        }
        return buf;
    }
}

// File: contracts/Chainlink/solidity-cborutils/CBOR.sol

library CBOR {
    using Buffer for Buffer.buffer;

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    function encodeType(Buffer.buffer memory buf, uint8 major, uint value) private pure {
        if(value <= 23) {
            buf.append(uint8((major << 5) | value));
        } else if(value <= 0xFF) {
            buf.append(uint8((major << 5) | 24));
            buf.appendInt(value, 1);
        } else if(value <= 0xFFFF) {
            buf.append(uint8((major << 5) | 25));
            buf.appendInt(value, 2);
        } else if(value <= 0xFFFFFFFF) {
            buf.append(uint8((major << 5) | 26));
            buf.appendInt(value, 4);
        } else if(value <= 0xFFFFFFFFFFFFFFFF) {
            buf.append(uint8((major << 5) | 27));
            buf.appendInt(value, 8);
        }
    }

    function encodeIndefiniteLengthType(Buffer.buffer memory buf, uint8 major) private pure {
        buf.append(uint8((major << 5) | 31));
    }

    function encodeUInt(Buffer.buffer memory buf, uint value) internal pure {
        encodeType(buf, MAJOR_TYPE_INT, value);
    }

    function encodeInt(Buffer.buffer memory buf, int value) internal pure {
        if(value >= 0) {
            encodeType(buf, MAJOR_TYPE_INT, uint(value));
        } else {
            encodeType(buf, MAJOR_TYPE_NEGATIVE_INT, uint(-1 - value));
        }
    }

    function encodeBytes(Buffer.buffer memory buf, bytes memory value) internal pure {
        encodeType(buf, MAJOR_TYPE_BYTES, value.length);
        buf.append(value);
    }

    function encodeString(Buffer.buffer memory buf, string memory value) internal pure {
        encodeType(buf, MAJOR_TYPE_STRING, bytes(value).length);
        buf.append(bytes(value));
    }

    function startArray(Buffer.buffer memory buf) internal pure {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
    }

    function startMap(Buffer.buffer memory buf) internal pure {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
    }

    function endSequence(Buffer.buffer memory buf) internal pure {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
    }
}

// File: contracts/Chainlink/ChainlinkLib.sol

library ChainlinkLib {
  uint256 internal constant defaultBufferSize = 256;

  using CBOR for Buffer.buffer;

  struct Run {
    bytes32 id;
    address callbackAddress;
    bytes4 callbackFunctionId;
    uint256 nonce;
    Buffer.buffer buf;
  }

  function initialize(
    Run memory self,
    bytes32 _id,
    address _callbackAddress,
    bytes4 _callbackFunction
  ) internal pure returns (ChainlinkLib.Run memory) {
    Buffer.init(self.buf, defaultBufferSize);
    self.id = _id;
    self.callbackAddress = _callbackAddress;
    self.callbackFunctionId = _callbackFunction;
    self.buf.startMap();
    return self;
  }

  function add(Run memory self, string memory _key, string memory _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeString(_value);
  }

  function addBytes(Run memory self, string memory _key, bytes memory _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeBytes(_value);
  }

  function addInt(Run memory self, string memory _key, int256 _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeInt(_value);
  }

  function addUint(Run memory self, string memory _key, uint256 _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeUInt(_value);
  }

  function addStringArray(Run memory self, string memory _key, string[] memory _values)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.startArray();
    for (uint256 i = 0; i < _values.length; i++) {
      self.buf.encodeString(_values[i]);
    }
    self.buf.endSequence();
  }

  function close(Run memory self) internal pure {
    self.buf.endSequence();
  }
}

// File: contracts/Chainlink/ENSResolver.sol

contract ENSResolver {
  function addr(bytes32 node) public view returns (address);
}

// File: contracts/Chainlink/interfaces/ENSInterface.sol

interface ENSInterface {

    // Logged when the owner of a node assigns a new owner to a subnode.
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    // Logged when the owner of a node transfers ownership to a new account.
    event Transfer(bytes32 indexed node, address owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    // Logged when the TTL of a node changes
    event NewTTL(bytes32 indexed node, uint64 ttl);


    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external;
    function setResolver(bytes32 node, address resolver) external;
    function setOwner(bytes32 node, address owner) external;
    function setTTL(bytes32 node, uint64 ttl) external;
    function owner(bytes32 node) external view returns (address);
    function resolver(bytes32 node) external view returns (address);
    function ttl(bytes32 node) external view returns (uint64);

}

// File: contracts/Chainlink/interfaces/LinkTokenInterface.sol

interface LinkTokenInterface {
  function allowance(address owner, address spender) external returns (bool success);
  function approve(address spender, uint256 value) external returns (bool success);
  function balanceOf(address owner) external returns (uint256 balance);
  function decimals() external returns (uint8 decimalPlaces);
  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
  function increaseApproval(address spender, uint256 subtractedValue) external;
  function name() external returns (string memory tokenName);
  function symbol() external returns (string memory tokenSymbol);
  function totalSupply() external returns (uint256 totalTokensIssued);
  function transfer(address to, uint256 value) external returns (bool success);
  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

// File: contracts/Chainlink/interfaces/ChainlinkRequestInterface.sol

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

// File: contracts/Chainlink/Chainlinked.sol

contract Chainlinked {
    using ChainlinkLib for ChainlinkLib.Run;
    using SafeMath for uint256;

    uint256 constant internal LINK = 10**18;
    uint256 constant private ARGS_VERSION = 1;
    bytes32 constant private ENS_TOKEN_SUBNAME = keccak256("link");
    bytes32 constant private ENS_ORACLE_SUBNAME = keccak256("oracle");

    ENSInterface private ens;
    bytes32 private ensNode;
    LinkTokenInterface private link;
    ChainlinkRequestInterface private oracle;
    uint256 private requests = 1;
    mapping(bytes32 => address) private unfulfilledRequests;

    event ChainlinkRequested(bytes32 id);
    event ChainlinkFulfilled(bytes32 id);
    event ChainlinkCancelled(bytes32 id);

    function newRun(
        bytes32 _specId,
        address _callbackAddress,
        bytes4 _callbackFunctionSignature
    ) internal pure returns (ChainlinkLib.Run memory) {
        ChainlinkLib.Run memory run;
        return run.initialize(_specId, _callbackAddress, _callbackFunctionSignature);
    }

    function chainlinkRequest(ChainlinkLib.Run memory _run, uint256 _amount)
        internal
        returns (bytes32)
    {
        return chainlinkRequestFrom(address(oracle), _run, _amount);
    }

    function chainlinkRequestFrom(address _oracle, ChainlinkLib.Run memory _run, uint256 _amount)
        internal
        returns (bytes32 requestId)
    {
        requestId = keccak256(abi.encodePacked(this, requests));
        _run.nonce = requests;
        _run.close();
        unfulfilledRequests[requestId] = _oracle;
        emit ChainlinkRequested(requestId);
        require(link.transferAndCall(_oracle, _amount, encodeRequest(_run)), "unable to transferAndCall to oracle");
        requests += 1;
    
        return requestId;
    }

    function cancelChainlinkRequest(bytes32 _requestId)
        internal
    {
        ChainlinkRequestInterface requested = ChainlinkRequestInterface(unfulfilledRequests[_requestId]);
        delete unfulfilledRequests[_requestId];
        emit ChainlinkCancelled(_requestId);
        requested.cancel(_requestId);
    }

    function setOracle(address _oracle) internal {
        oracle = ChainlinkRequestInterface(_oracle);
    }

    function setLinkToken(address _link) internal {
        link = LinkTokenInterface(_link);
    }

    function chainlinkToken()
        internal
        view
        returns (address)
    {
        return address(link);
    }

    function oracleAddress()
        internal
        view
        returns (address)
    {
        return address(oracle);
    }

    function addExternalRequest(address _oracle, bytes32 _requestId)
        internal
        isUnfulfilledRequest(_requestId)
    {
        unfulfilledRequests[_requestId] = _oracle;
    }

    function newChainlinkWithENS(address _ens, bytes32 _node)
        internal
        returns (address, address)
    {
        ens = ENSInterface(_ens);
        ensNode = _node;
        ENSResolver resolver = ENSResolver(ens.resolver(ensNode));
        bytes32 linkSubnode = keccak256(abi.encodePacked(ensNode, ENS_TOKEN_SUBNAME));
        setLinkToken(resolver.addr(linkSubnode));
        return (address(link), updateOracleWithENS());
    }

    function updateOracleWithENS()
        internal
        returns (address)
    {
        ENSResolver resolver = ENSResolver(ens.resolver(ensNode));
        bytes32 oracleSubnode = keccak256(abi.encodePacked(ensNode, ENS_ORACLE_SUBNAME));
        setOracle(resolver.addr(oracleSubnode));
        return address(oracle);
    }

    function encodeRequest(ChainlinkLib.Run memory _run)
    internal
    view
    returns (bytes memory)
    {
        return abi.encodeWithSelector(
        oracle.requestData.selector,
        0, // overridden by onTokenTransfer
        0, // overridden by onTokenTransfer
        ARGS_VERSION,
        _run.id,
        _run.callbackAddress,
        _run.callbackFunctionId,
        _run.nonce,
        _run.buf.buf);
    }

    function completeChainlinkFulfillment(bytes32 _requestId)
        internal
        checkChainlinkFulfillment(_requestId)
    {}

    modifier checkChainlinkFulfillment(bytes32 _requestId) {
        require(msg.sender == unfulfilledRequests[_requestId], "source must be the oracle of the request");
        delete unfulfilledRequests[_requestId];
        emit ChainlinkFulfilled(_requestId);
        _;
    }

    modifier isUnfulfilledRequest(bytes32 _requestId) {
        require(unfulfilledRequests[_requestId] == address(0), "Request is already fulfilled");
        _;
    }
}

// File: contracts/ProtectedWallet.sol

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
    bytes32 constant LIMIT_JOB =                bytes32("5bf96634ddb9498e948b2674be599060");
    bytes32 constant RECOVER_JOB =              bytes32("43b41acaa7cc43dfacab4ac701dc7173");
    bytes32 constant ONETIME_WITHDRAW_JOB =     bytes32("1b1ac6af395f41bb982f856f10b0ce32");
    bytes32 constant ONETIME_TRANSFEREXT_JOB =  bytes32("a354053ad6d54b739369b86f6c057275");
    bytes32 constant ONETIME_WITHDRAWEXT_JOB =  bytes32("20c9ea65c1084740a88189225d7dee17");

    constructor(uint _ein, uint _dailyLimit, address snowflakeAddress, bytes32 passHash, address clientRaindropAddr) 
    public 
    SnowflakeResolver("Your personal protected wallet", "Protect your funds without locking them up in cold storage", snowflakeAddress, true, true) 
    {
        setLinkToken(0x01BE23585060835E02B77ef475b0Cc51aA1e0709);
        setOracle(0x7F30D3b10a112D81E629A9d7B8A5122F7afE5631);
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

    // Request to adjust daily limit
    function requestChangeDailyLimit(uint newDailyLimit) public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the ein that owns this wallet can make withdrawals");
        require(pendingDailyLimit == 0, "A change daily limit request is already in progress");
        require(timeOfLast2FA + 5 minutes < now);
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
        require(timeOfLast2FA + 5 minutes < now);
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
        require(timeOfLast2FA + 5 minutes < now);
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
        require(timeOfLast2FA + 5 minutes < now);
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
        require(timeOfLast2FA + 5 minutes < now);
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

    function resetChainlinkState() public {
        require(idRegistry.getEIN(msg.sender) == ein, "Only the protected wallet associated ein can invoke this function");
        require(now > timeOfLast2FA + 1 hours, "Can only invoke this function at least one hour after the last chainlink request");
        
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

// File: contracts/ProtectedWalletFactory.sol

/**
   1. Wallet allows the owning hydroId or any whitelisted address
   to deposit hydro tokens freely
   2. Upon wallet creation, the hydroId specifies the token withdrawal
   daily limit.  This daily limit does not accumulate.
   3. The wallet includes the option to do an unlimited withdrawal after
   going through 2FA facilitated by the chainlink external adapter
   4. In case the chainlink node and/or the hydrogen api. are not operational
   there exists a one time use password recovery option.  This one time use password
   deposits all of the hydro tokens into the calling address and terminates the
   wallet.
  */

  //1. Get the contracts working with ein -- done
  //2. Get deposits and withdrawals working with snowflake -- done
  //3. Get deposits and withdrawals working w/external addresses -- done
  //4. Commit reveal recovery working -- done


contract ProtectedWalletFactory is SnowflakeResolver {
    using SafeMath for uint;
    
    IdentityRegistryInterface idRegistry;
    SnowflakeInterface        snowflake;
    ClientRaindropInterface   clientRaindrop;

    mapping (uint => address) private einToWallet;
    mapping (uint => bool) private    einHasDeleted;
    mapping (address => bool) private isHydroIdAddress;
    mapping (uint => string) private  einToHydroId;

    uint signUpFee =          1 ether;
    uint standardDailyLimit = 100 ether;
    bytes32 defaultPass =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000000000000000000000000000000;

    modifier onlyWallet(uint ein) {
        require(msg.sender == einToWallet[ein], "Only the wallet affiliated with this ein can call this function");
        _;
    }

    constructor(address snowflakeAddress, address clientRaindropAddr) 
    SnowflakeResolver("Protected wallet factory", "Generate your unique protected wallet", snowflakeAddress, true, true)
    public {
        setClientRaindropAddress(clientRaindropAddr);
        setSnowflakeAddress(snowflakeAddress);
    }

    function onAddition(uint ein, uint, bytes memory extraData) public senderIsSnowflake() returns (bool) {
        (address hydroAddr, string memory hydroId) = clientRaindrop.getDetails(ein);
        isHydroIdAddress[hydroAddr] = true;
        einToHydroId[ein] = hydroId;
        if (extraData.length == 32) {
            bytes32 passHash = bytesToBytes32(extraData);
            address wallet = generateWalletPassword(ein, passHash);
            einToWallet[ein] = wallet;
            return true;
        }
        else {
            address wallet = generateWalletPassword(ein, defaultPass);
            einToWallet[ein] = wallet;
            return true;
        }
    }

    function setClientRaindropAddress(address clientRaindropAddr) public onlyOwner() {
        clientRaindrop = ClientRaindropInterface(clientRaindropAddr);
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);
        snowflake = SnowflakeInterface(snowflakeAddress);
        idRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
    }

    function onRemoval(uint, bytes memory) public senderIsSnowflake() returns (bool) {
        return true;
    }
    
    // For use after an ein has registered with this resolver, but has deleted
    // one or more wallets
    function generateNewWallet(uint ein, bytes memory _passHash) public returns (address) {
        require(ein == idRegistry.getEIN(msg.sender), "Only an associated address can generate a new wallet");
        require(einHasDeleted[ein] == true, "Ein must have deleted the previous wallet");
        if (_passHash.length == 32) {
            bytes32 passHash = bytesToBytes32(_passHash);
            address wallet = generateWalletPassword(ein, passHash);
            einToWallet[ein] = wallet;
            return wallet;
        }
        else {
            address wallet = generateWalletPassword(ein, defaultPass);
            einToWallet[ein] = wallet;
            return wallet;
        }
    } 

    function generateWalletPassword(uint ein, bytes32 passHash) internal returns (address) {
        ProtectedWallet protectedWallet = new ProtectedWallet(ein, standardDailyLimit, snowflakeAddress, passHash, address(clientRaindrop));
        return address(protectedWallet);
    }

    function deleteWallet(uint ein) public onlyWallet(ein) returns (bool) {
        delete einToWallet[ein];
        einHasDeleted[ein] = true;
        return true;
    }

    function getWalletByEIN(uint ein) public view returns (address) {
        return einToWallet[ein];
    }

    function getWalletByAddress(address addr) public view returns (address) {
        uint _ein = idRegistry.getEIN(addr);
        return getWalletByEIN(_ein);
    }

    function getSnowflakeAddress() public view returns (address) {
        return snowflakeAddress;
    }

    // Copied from stack exchange -- do not trust
    function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
        bytes32 out;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[0 + i] & 0xFF) >> (i * 8);
        }
        return out;
    }

}
