// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0; 

error InvalidTier();
error InvalidAddress();
error InvalidAmount();
error NameTooLong();
error InvalidID();
error InsufficientBalance();
error UnauthorizedCaller();
error MustBeOwnerOrAdmin();
error InvalidWhitelistTier();
error NotWhitelisted();
error ContractHacked();
    

contract GasContract {
    uint256 public immutable totalSupply; // cannot be updated
    
    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    mapping(address => bool) public isAdministrator;
    bool public isReady = false;
    uint8 wasLastOdd = 1;
    address public contractOwner;

    History[] public paymentHistory; // when a payment was updated

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    mapping(address => uint256) public isOddWhitelistUser;
    
    struct ImportantStruct {
        uint256 amount;
        bool paymentStatus;
        address sender;
    }
    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        if (!checkForAdmin(msg.sender) && msg.sender != contractOwner) {
            revert MustBeOwnerOrAdmin();
            _;
        } else {
            _;
        }
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        if (msg.sender != sender) {
            revert NotWhitelisted();
            _;
        }
        uint256 usersTier = whitelist[msg.sender];
        if (usersTier < 1 || usersTier > 4) {
            revert NotWhitelisted();
            _;
        }
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

   constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
            }
        }
        balances[msg.sender] = _totalSupply;
        emit supplyChanged(msg.sender, _totalSupply);
    }
    
    function checkForAdmin(address _user) public view returns (bool admin_) {
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin_ = true;
            }
        }
        return admin_;
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function addHistory(address _updateAddress)
        public
        returns (bool)
    {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);

        return true;
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool) {
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        if (bytes(_name).length >= 9) {
            revert NameTooLong();
        }
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);

        return true;
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        if (_tier >= 255) {
            revert InvalidTier();
        }
        
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }
        
        uint8 wasLastAddedOdd = wasLastOdd;
        if (wasLastAddedOdd == 1) {
            wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else if (wasLastAddedOdd == 0) {
            wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else {
            revert ContractHacked();
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) public checkIfWhiteListed(msg.sender) {
        whiteListStruct[msg.sender] = ImportantStruct(_amount, true, msg.sender);
        
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance();
        }
        if (_amount <= 3) {
            revert InvalidAmount();
        }
        
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelist[msg.sender];
        balances[_recipient] -= whitelist[msg.sender];
        
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    fallback() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}