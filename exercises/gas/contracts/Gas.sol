// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract GasContract {
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }
    
    struct ImportantStruct {                    //
        uint256 valueA; // max 3 digits          //
        uint256 bigValue;                       //
        uint256 valueB; // max 3 digits          //
    }                                           //

    uint256 public immutable totalSupply; // cannot be updated       //
    uint256 private paymentCounter = 0;
    mapping(address => uint256) private balances;
    address public contractOwner;
    mapping(address => Payment[]) private payments;
    mapping(address => uint256) public whitelist;
    mapping(address => bool) private _administrators;     //
    address[5] public administrators;
    History[] private paymentHistory; // when a payment was updated
    bool wasLastOdd = true;
    mapping(address => bool) public isOddWhitelistUser;
    mapping(address => ImportantStruct) public whiteListStruct;

    modifier onlyAdminOrOwner() {
        require(checkForAdmin(msg.sender) || msg.sender == contractOwner, "Invalid Caller");
        _;
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        require(senderOfTx == sender, "Origin is not sender");
        uint256 usersTier = whitelist[senderOfTx];
        require(usersTier > 0 && usersTier < 4, "Incorrect tier");
        _;
    }

    event AddedToWhitelist(address userAddress, uint256 tier);
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );


    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                _administrators[_admins[ii]] = true;
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    balances[contractOwner] = _totalSupply;
                    emit supplyChanged(_admins[ii], _totalSupply);
                } else {
                    balances[_admins[ii]] = 0;
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function getPaymentHistory() external payable returns (History[] memory) {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool) {              //
        return _administrators[_user];                                              //
    }                                                                               //

    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getTradingMode() external pure returns (bool) {                        //
        return true;                                                                //
    }                                                                               //

    function addHistory(address _updateAddress) public {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
    }

    function getPayments(address _user) external view returns (Payment[] memory payments_) {
        return payments[_user];
    }

    mapping(uint256 => uint256) private paymentIdIndex;
    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        address senderOfTx = msg.sender;
        require(balances[senderOfTx] >= _amount, "Insufficient Balance");
        require(bytes(_name).length < 9, "Name exceeds 8 characters");
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        paymentIdIndex[payment.paymentID] = payments[senderOfTx].length;
        payments[senderOfTx].push(payment);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(
            _ID > 0,
            "Gas Contract - Update Payment function - ID must be greater than 0"
        );
        require(
            _amount > 0,
            "Gas Contract - Update Payment function - Amount must be greater than 0"
        );
        require(
            _user != address(0),
            "Gas Contract - Update Payment function - Administrator must have a valid non zero address"
        );

        address senderOfTx = msg.sender;

        uint index = paymentIdIndex[_ID];
        if (index < payments[_user].length && payments[_user][index].paymentID == _ID) {
            payments[_user][index].adminUpdated = true;
            payments[_user][index].admin = _user;
            payments[_user][index].paymentType = _type;
            payments[_user][index].amount = _amount;
            addHistory(_user);
            emit PaymentUpdated(
                senderOfTx,
                _ID,
                _amount,
                payments[_user][index].recipientName
            );
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        external
        onlyAdminOrOwner
    {
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        isOddWhitelistUser[_userAddrs] = wasLastOdd;
        wasLastOdd = !wasLastOdd;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        uint senderBalance = balances[senderOfTx];
        uint senderTier = whitelist[senderOfTx];
        require(senderBalance >= _amount, "Sender has insufficient Balance");
        require(_amount > 3, "Amount less than 3");
        balances[senderOfTx] = (senderBalance + senderTier) - _amount;
        balances[_recipient] = (balances[_recipient] + _amount) - senderTier;
        whiteListStruct[senderOfTx] = _struct;
        emit WhiteListTransfer(_recipient);
    }
}
