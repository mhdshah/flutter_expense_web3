// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract ExpenseContract {
    address public owner;

    event Deposit(
        address indexed _from,
        uint _amount,
        string _reason,
        uint _timestamp
    );

    event Withdraw(
        address indexed _to,
        uint _amount,
        string _reason,
        uint _timestamp
    );

    enum TransactionType {
        Credit,
        Debit
    }

    // Transaction modal
    struct Transaction {
        // It's similar to user id
        address user;
        uint amount;
        string reason;
        uint timestamp;
        TransactionType transactionType;
    }

    Transaction[] public transactions;
    mapping(address => uint) public balances;

    constructor() {
        owner = msg.sender;
    }

    // Modifier to check that the caller is the owner of
    // the contract.
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        // Underscore is a special character only used inside
        // a function modifier and it tells Solidity to
        // execute the rest of the code.
        _;
    }

    function deposit(uint _amount, string memory _reason) public payable {
        require(_amount > 0, "Deposit amount should be greater than 0");
        balances[msg.sender] += _amount;
        transactions.push(
            Transaction({
                user: msg.sender,
                amount: _amount,
                reason: _reason,
                timestamp: block.timestamp,
                transactionType: TransactionType.Credit
            })
        );
        emit Deposit(msg.sender, _amount, _reason, block.timestamp);
    }

    function withdraw(uint _amount, string memory _reason) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        transactions.push(
            Transaction({
                user: msg.sender,
                amount: _amount,
                reason: _reason,
                timestamp: block.timestamp,
                transactionType: TransactionType.Debit
            })
        );
        payable(msg.sender).transfer(_amount);
        emit Withdraw(msg.sender, _amount, _reason, block.timestamp);
    }

    function getBalance(address _account) public view returns (uint) {
        return balances[_account];
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _index
    )
        public
        view
        returns (address, uint, string memory, uint, TransactionType)
    {
        require(_index < transactions.length, "Index out of bounds");

        Transaction memory transaction = transactions[_index];
        return (
            transaction.user,
            transaction.amount,
            transaction.reason,
            transaction.timestamp,
            transaction.transactionType
        );
    }

    function getAllTransaction()
        public
        view
        returns (
            address[] memory,
            uint[] memory,
            string[] memory,
            uint[] memory,
            TransactionType[] memory
        )
    {
        address[] memory users = new address[](transactions.length);
        uint[] memory amounts = new uint[](transactions.length);
        string[] memory reasons = new string[](transactions.length);
        uint[] memory timestamps = new uint[](transactions.length);
        TransactionType[] memory transactionTypes = new TransactionType[](
            transactions.length
        );

        for (uint i = 0; i < transactions.length; i++) {
            users[i] = transactions[i].user;
            amounts[i] = transactions[i].amount;
            reasons[i] = transactions[i].reason;
            timestamps[i] = transactions[i].timestamp;
            transactionTypes[i] = transactions[i].transactionType;
        }
        return (users, amounts, reasons, timestamps, transactionTypes);
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
}
