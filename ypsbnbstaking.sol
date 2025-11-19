// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YPSBNBStaking is ReentrancyGuard, Ownable {
    address payable public treasury;
    
    struct BNBStake {
        uint256 amount;
        uint256 planDays;
        uint256 startTime;
        uint256 apy;
        uint256 multiplier;
        bool active;
        bool withdrawn;
    }
    
    mapping(address => BNBStake[]) public userBNBStakes;
    mapping(uint256 => uint256) public planAPY;
    mapping(uint256 => uint256) public planMultiplier;
    
    event BNBStaked(address indexed user, uint256 amount, uint256 planDays, uint256 stakeId);
    event BNBWithdrawn(address indexed user, uint256 amount, uint256 rewards);
    event EmergencyBNBWithdrawn(address indexed owner, uint256 amount);
    
    constructor(address payable _treasury) {
        treasury = _treasury;
        _transferOwnership(msg.sender);
        
        planAPY[30] = 15;
        planAPY[100] = 45;
        planAPY[200] = 70;
        planAPY[360] = 100;
        
        planMultiplier[30] = 1;
        planMultiplier[100] = 4;
        planMultiplier[200] = 7;
        planMultiplier[360] = 12;
    }
    
    function stakeBNB(uint256 planDays) external payable nonReentrant {
        require(msg.value >= 0.01 ether, "Minimum 0.01 BNB required");
        require(planAPY[planDays] > 0, "Invalid plan");
        
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "BNB transfer failed");
        
        userBNBStakes[msg.sender].push(BNBStake({
            amount: msg.value,
            planDays: planDays,
            startTime: block.timestamp,
            apy: planAPY[planDays],
            multiplier: planMultiplier[planDays],
            active: true,
            withdrawn: false
        }));
        
        uint256 stakeId = userBNBStakes[msg.sender].length - 1;
        emit BNBStaked(msg.sender, msg.value, planDays, stakeId);
    }
    
    function calculateBNBRewards(address user, uint256 stakeId) public view returns (uint256 bnbRewards, uint256 ypsTokens) {
        BNBStake memory stake = userBNBStakes[user][stakeId];
        require(stake.active, "Stake not active");
        
        uint256 timeStaked = block.timestamp - stake.startTime;
        uint256 daysStaked = timeStaked / 1 days;
        
        if (daysStaked >= stake.planDays) {
            bnbRewards = (stake.amount * stake.apy) / 100;
            uint256 bnbValue = stake.amount / 10**18;
            ypsTokens = (bnbValue * 5 * stake.multiplier) / 10;
        }
    }
    
    function withdrawBNB(uint256 stakeId) external nonReentrant {
        BNBStake storage stake = userBNBStakes[msg.sender][stakeId];
        require(stake.active, "Stake not active");
        require(!stake.withdrawn, "Already withdrawn");
        
        (uint256 bnbRewards, uint256 ypsTokens) = calculateBNBRewards(msg.sender, stakeId);
        require(bnbRewards > 0, "No rewards available yet");
        
        stake.active = false;
        stake.withdrawn = true;
        
        uint256 totalAmount = stake.amount + bnbRewards;
        (bool success, ) = msg.sender.call{value: totalAmount}("");
        require(success, "BNB transfer failed");
        
        emit BNBWithdrawn(msg.sender, stake.amount, bnbRewards);
    }
    
    function getUserBNBStakes(address user) external view returns (BNBStake[] memory) {
        return userBNBStakes[user];
    }
    
    function getBNBStakeCount(address user) external view returns (uint256) {
        return userBNBStakes[user].length;
    }
    
    function setTreasury(address payable _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }
    
    function setPlanAPY(uint256 planDays, uint256 apy) external onlyOwner {
        planAPY[planDays] = apy;
    }
    
    function setPlanMultiplier(uint256 planDays, uint256 multiplier) external onlyOwner {
        planMultiplier[planDays] = multiplier;
    }
    
    function emergencyWithdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = owner().call{value: balance}("");
            require(success, "Emergency withdrawal failed");
            emit EmergencyBNBWithdrawn(owner(), balance);
        }
    }
    
    receive() external payable {}
    
    function getContractBNBBalance() external view returns (uint256) {
        return address(this).balance;
    }
}