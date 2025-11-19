// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YPSUSDTStaking is ReentrancyGuard, Ownable {
    IERC20 public usdt;
    address public treasury;
    
    struct Stake {
        uint256 amount;
        uint256 planDays;
        uint256 startTime;
        uint256 apy;
        uint256 multiplier;
        bool active;
        bool withdrawn;
    }
    
    mapping(address => Stake[]) public userStakes;
    mapping(uint256 => uint256) public planAPY;
    mapping(uint256 => uint256) public planMultiplier;
    
    event Staked(address indexed user, uint256 amount, uint256 planDays, uint256 stakeId);
    event Withdrawn(address indexed user, uint256 amount, uint256 rewards);
    event EmergencyWithdrawn(address indexed owner, uint256 amount);
    
    constructor(address _usdt, address _treasury) {
        usdt = IERC20(_usdt);
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
    
    function stakeUSDT(uint256 amount, uint256 planDays) external nonReentrant {
        require(amount >= 10 * 10**18, "Minimum 10 USDT required");
        require(planAPY[planDays] > 0, "Invalid plan");
        
        require(usdt.transferFrom(msg.sender, treasury, amount), "USDT transfer failed");
        
        userStakes[msg.sender].push(Stake({
            amount: amount,
            planDays: planDays,
            startTime: block.timestamp,
            apy: planAPY[planDays],
            multiplier: planMultiplier[planDays],
            active: true,
            withdrawn: false
        }));
        
        uint256 stakeId = userStakes[msg.sender].length - 1;
        emit Staked(msg.sender, amount, planDays, stakeId);
    }
    
    function calculateRewards(address user, uint256 stakeId) public view returns (uint256 usdtRewards, uint256 ypsTokens) {
        Stake memory stake = userStakes[user][stakeId];
        require(stake.active, "Stake not active");
        
        uint256 timeStaked = block.timestamp - stake.startTime;
        uint256 daysStaked = timeStaked / 1 days;
        
        if (daysStaked >= stake.planDays) {
            usdtRewards = (stake.amount * stake.apy) / 100;
            uint256 usdValue = stake.amount / 10**18;
            ypsTokens = (usdValue * 5 * stake.multiplier) / 10;
        }
    }
    
    function withdraw(uint256 stakeId) external nonReentrant {
        Stake storage stake = userStakes[msg.sender][stakeId];
        require(stake.active, "Stake not active");
        require(!stake.withdrawn, "Already withdrawn");
        
        (uint256 usdtRewards, uint256 ypsTokens) = calculateRewards(msg.sender, stakeId);
        require(usdtRewards > 0, "No rewards available yet");
        
        stake.active = false;
        stake.withdrawn = true;
        
        uint256 totalAmount = stake.amount + usdtRewards;
        require(usdt.transferFrom(treasury, msg.sender, totalAmount), "Reward transfer failed");
        
        emit Withdrawn(msg.sender, stake.amount, usdtRewards);
    }
    
    function getUserStakes(address user) external view returns (Stake[] memory) {
        return userStakes[user];
    }
    
    function getStakeCount(address user) external view returns (uint256) {
        return userStakes[user].length;
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }
    
    function setPlanAPY(uint256 planDays, uint256 apy) external onlyOwner {
        planAPY[planDays] = apy;
    }
    
    function setPlanMultiplier(uint256 planDays, uint256 multiplier) external onlyOwner {
        planMultiplier[planDays] = multiplier;
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        if (balance > 0) {
            usdt.transfer(owner(), balance);
            emit EmergencyWithdrawn(owner(), balance);
        }
    }
    
    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
}