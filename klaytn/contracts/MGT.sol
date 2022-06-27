// SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";

contract MGT is Context, Operator, ERC20Burnable {
    string _name;
    string _symbol;

    address public fund;
    uint256 public fee;
    mapping(address => bool) public gsOpeartors;


    uint256 public stakedTotalSupply;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lockupTime;

    uint256 public constant feeMin = 300;
    uint256 public constant feeMax = 5000;

    event RegisterGSOperator(address gsOpeartor, uint256 at);
    event ChangeFund(address fund, uint256 at);
    event ChangeFee(uint256 newFee, uint256 oldFee, uint256 at);
    event Stake(address indexed account, uint256 amount, uint256 lockup, uint256 at);
    event Withdraw(address indexed account, uint256 amount, uint256 at);
    event ChangeLockupTime(address indexed account, uint256 lockup, uint256 at);

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    // Operator method
    constructor(string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;

        fund = msg.sender;
        fee = 3000; // 30%
    }

    function mintInitialAmount(uint256 _amount, uint256 _total) public onlyOperator {
        require(totalSupply() == 0, "already minted");
        require(_amount <= _total && _total > 0, "out of range");
        
        _mint(msg.sender, _amount);
        _mint(address(this), _total.sub(_amount));
    }

    function burn(uint256 amount) public onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOperator {
        super.burnFrom(account, amount);
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        _token.transfer(_to, _amount);
    }

    function registerGSOperator(address _gsOperator) public {
        require(msg.sender == operator() || gsOpeartors[msg.sender] == true, "only gsOperator or operator can");
        require(_gsOperator != address(0), "_gsOperator address is zero");
        require(gsOpeartors[_gsOperator] == false, "gsOpeartor already registerd");
        gsOpeartors[_gsOperator] = true;
        emit RegisterGSOperator(_gsOperator, block.number);
    }

    // Fund method
    function changeFund(address _fund) public {
        require(msg.sender == fund || msg.sender == operator(), "only fund or operator can");
        require(_fund != address(0), "_fund address is zero");
        fund = _fund;
        emit ChangeFund(fund, block.number);
    }    

    function chanageFee(uint256 _fee) public {
        require(msg.sender == fund, "only fund can");
        require(_fee >= feeMin && _fee <= feeMax, "check fee range");
        uint256 oldFee = fee;
        fee = _fee;
        emit ChangeFee(fee, oldFee, block.number);
    }

    // Game operator method
    modifier onlyGS() {
        require(gsOpeartors[msg.sender] == true, "only GS can");
        _;
    }

    function offerToken(address recipient, uint256 amount) public onlyGS {
        _transfer(address(this), recipient, amount);
    }

    function retrieveToken(address sender, uint256 amount) public onlyGS {
        uint256 feeAmount = amount.mul(fee).div(10000);
        uint256 retrieveAmount = amount.sub(feeAmount);

        if (retrieveAmount > 0) _transfer(sender, address(this), retrieveAmount);
        if (feeAmount > 0) _transfer(sender, fund, feeAmount);
    }

    function stakedBalanceOf(address account) public view returns (uint256) {
        return stakedBalances[account];
    }

    function stake(address account, uint256 amount, uint256 lockup) public onlyGS {
        require(amount > 0, "cannot stake 0");
        require(lockup > block.timestamp, "lockup time cannot not be before now");

        stakedTotalSupply = stakedTotalSupply.add(amount);
        stakedBalances[account] = stakedBalances[account].add(amount);
        
        _transfer(account, address(this), amount);
        lockupTime[account] = lockup;

        emit Stake(account, amount, lockup, block.number);
    }

    function withdraw(address account, uint256 amount) public onlyGS {
        require(amount > 0, "cannot withdraw 0");
        require(lockupTime[account] < block.timestamp, "still lockup");

        uint256 _stakedBalance = stakedBalances[account];
        require(_stakedBalance  >= amount, "withdraw request greater than staked amount");

        stakedTotalSupply = stakedTotalSupply.sub(amount);
        stakedBalances[account] = _stakedBalance.sub(amount);
        _transfer(address(this), account, amount);

        emit Withdraw(account, amount, block.number);
    }

    function changeLockupTime(address account, uint256 lockup) public onlyGS {
        require(lockup > block.timestamp, "lockup time cannot not be before now");
        lockupTime[account] = lockup;

        emit ChangeLockupTime(account, lockup, block.timestamp);
    }
}
