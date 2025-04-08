// SPDX-License-Identifier: MIT pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; import "@openzeppelin/contracts/access/Ownable.sol"; import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; import "@openzeppelin/contracts/security/Pausable.sol";

contract CREPSStaking is Ownable, ReentrancyGuard, Pausable { IERC20 public crepsToken; address public rewardWallet;

uint256 public apy; // e.g., 20000 = 200.00%
uint256 public lockPeriod;
uint256 public constant APY_DIVISOR = 20000;
uint256 public maxAPY = 20000; // 200%
uint256 public maxStakePerUser = 1_000_000 * 10**18; // Exemple : 1 million CREPS

struct StakeInfo {
    uint256 amount;
    uint256 startTime;
    uint256 lastClaimTime;
}

mapping(address => StakeInfo) public stakes;
mapping(address => uint256) public pendingRewards;
address[] public stakers;
mapping(address => bool) private hasStaked;

event Staked(address indexed user, uint256 amount, uint256 timestamp);
event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);
event RewardWalletUpdated(address newWallet);
event APYUpdated(uint256 newAPY);
event LockPeriodUpdated(uint256 newLockPeriod);
event EmergencyWithdraw(uint256 amount);
event Paused(address);
event Unpaused(address);

constructor(
    address _crepsToken,
    address _rewardWallet,
    uint256 _initialAPY,
    uint256 _initialLockPeriod
) {
    require(_initialAPY <= maxAPY, "APY trop eleve");
    crepsToken = IERC20(_crepsToken);
    rewardWallet = _rewardWallet;
    apy = _initialAPY;
    lockPeriod = _initialLockPeriod;
}

modifier onlyStaker() {
    require(stakes[msg.sender].amount > 0, "Aucun token jalonne");
    _;
}

function stake(uint256 amount) external nonReentrant whenNotPaused {
    require(amount > 0, "Montant doit etre superieur a 0");
    StakeInfo storage userStake = stakes[msg.sender];
    require(userStake.amount + amount <= maxStakePerUser, "Dépassement du stake maximal");

    if (userStake.amount > 0) {
        pendingRewards[msg.sender] += calculateReward(msg.sender);
        userStake.lastClaimTime = block.timestamp;
    } else {
        userStake.startTime = block.timestamp;
        userStake.lastClaimTime = block.timestamp;
        if (!hasStaked[msg.sender]) {
            hasStaked[msg.sender] = true;
            stakers.push(msg.sender);
        }
    }

    userStake.amount += amount;
    require(crepsToken.transferFrom(msg.sender, address(this), amount), "Transfert echoue");

    emit Staked(msg.sender, amount, block.timestamp);
}

function unstake() external nonReentrant onlyStaker whenNotPaused {
    StakeInfo storage userStake = stakes[msg.sender];
    require(block.timestamp >= userStake.startTime + lockPeriod, "Periode de verrouillage non ecoulee");

    uint256 amount = userStake.amount;
    uint256 reward = pendingRewards[msg.sender] + calculateReward(msg.sender);

    userStake.amount = 0;
    userStake.startTime = 0;
    userStake.lastClaimTime = 0;
    pendingRewards[msg.sender] = 0;

    require(crepsToken.transfer(msg.sender, amount), "Echec du retour des tokens");

    if (reward > 0) {
        require(crepsToken.balanceOf(rewardWallet) >= reward, "RewardWallet insuffisant");
        require(crepsToken.transferFrom(rewardWallet, msg.sender, reward), "Echec de la recompense");
        emit RewardsClaimed(msg.sender, reward, block.timestamp);
    }

    emit Unstaked(msg.sender, amount, block.timestamp);
}

function claimRewards() external nonReentrant onlyStaker whenNotPaused {
    uint256 reward = pendingRewards[msg.sender] + calculateReward(msg.sender);
    require(reward > 0, "Aucune recompense a reclamer");
    require(crepsToken.balanceOf(rewardWallet) >= reward, "RewardWallet insuffisant");

    pendingRewards[msg.sender] = 0;
    stakes[msg.sender].lastClaimTime = block.timestamp;

    require(crepsToken.transferFrom(rewardWallet, msg.sender, reward), "Echec de la recompense");
    emit RewardsClaimed(msg.sender, reward, block.timestamp);
}

function calculateReward(address user) public view returns (uint256) {
    StakeInfo memory userStake = stakes[user];
    if (userStake.amount == 0) return 0;

    uint256 timeSinceLastClaim = block.timestamp - userStake.lastClaimTime;
    if (timeSinceLastClaim == 0) return 0;

    uint256 annualReward = (userStake.amount * apy) / APY_DIVISOR;
    return (annualReward * timeSinceLastClaim) / 365 days;
}

function viewPendingRewards(address user) external view returns (uint256) {
    return pendingRewards[user] + calculateReward(user);
}

function getStakeOf(address user) external view returns (uint256) {
    return stakes[user].amount;
}

function getTotalStaked() external view returns (uint256 total) {
    for (uint i = 0; i < stakers.length; i++) {
        total += stakes[stakers[i]].amount;
    }
}

function checkRewardWalletBalance() external view returns (uint256) {
    return crepsToken.balanceOf(rewardWallet);
}

function setRewardWallet(address _newRewardWallet) external onlyOwner {
    require(_newRewardWallet != address(0), "Adresse invalide");
    rewardWallet = _newRewardWallet;
    emit RewardWalletUpdated(_newRewardWallet);
}

function setAPY(uint256 _newAPY) external onlyOwner {
    require(_newAPY > 0 && _newAPY <= maxAPY, "APY invalide");
    for (uint i = 0; i < stakers.length; i++) {
        address staker = stakers[i];
        pendingRewards[staker] += calculateReward(staker);
        stakes[staker].lastClaimTime = block.timestamp;
    }
    apy = _newAPY;
    emit APYUpdated(_newAPY);
}

function setLockPeriod(uint256 _newLockPeriod) external onlyOwner {
    require(_newLockPeriod > 0, "Periode invalide");
    lockPeriod = _newLockPeriod;
    emit LockPeriodUpdated(_newLockPeriod);
}

function emergencyWithdraw(uint256 amount) external onlyOwner {
    uint256 contractBalance = crepsToken.balanceOf(address(this));
    uint256 totalStaked = 0;
    for (uint i = 0; i < stakers.length; i++) {
        totalStaked += stakes[stakers[i]].amount;
    }
    require(contractBalance >= totalStaked + amount, "Fonds insuffisants");
    require(crepsToken.transfer(owner(), amount), "Echec retrait urgence");
    emit EmergencyWithdraw(amount);
}

function pause() external onlyOwner {
    _pause();
    emit Paused(msg.sender);
}

function unpause() external onlyOwner {
    _unpause();
    emit Unpaused(msg.sender);
}

}
