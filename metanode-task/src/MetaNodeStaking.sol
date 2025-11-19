// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MetaNodeStaking
 * @dev A multi-token staking system with MetaNode token rewards
 * @author MetaNode Task
 */
contract MetaNodeStaking is Ownable, Pausable, ReentrancyGuard {
    
    // Struct definitions
    struct Pool {
        IERC20 stToken;                    // 质押代币地址
        uint256 poolWeight;                // 质押池权重
        uint256 lastRewardBlock;           // 最后一次计算奖励的区块号
        uint256 accMetaNodePerST;          // 每个质押代币累积的MetaNode数量
        uint256 stTokenAmount;             // 池中的总质押代币量
        uint256 minDepositAmount;          // 最小质押金额
        uint256 unstakeLockedBlocks;       // 解除质押的锁定区块数
        bool exists;                       // 池是否存在
    }
    
    struct UnstakeRequest {
        uint256 amount;                    // 解质押数量
        uint256 unlockBlock;               // 解锁区块号
        bool processed;                    // 是否已处理
    }
    
    struct User {
        uint256 stAmount;                  // 用户质押的代币数量
        uint256 finishedMetaNode;          // 已分配的MetaNode数量
        uint256 pendingMetaNode;           // 待领取的MetaNode数量
        mapping(uint256 => UnstakeRequest) requests; // 解质押请求
        uint256[] requestIds;              // 请求ID列表
    }
    
    // State variables
    ERC20 public metaNodeToken;           // MetaNode奖励代币
    uint256 public metaNodePerBlock;      // 每区块产生的MetaNode数量
    uint256 public totalPoolWeight;       // 总池权重
    uint256 public startBlock;            // 开始奖励的区块号
    
    // Mappings
    mapping(uint256 => Pool) public pools;              // 质押池映射
    mapping(uint256 => mapping(address => User)) public users; // 用户数据映射
    mapping(address => bool) public supportedTokens;     // 支持的代币映射
    
    // Arrays
    uint256[] public poolIds;                             // 池ID列表
    
    // Counters
    uint256 private _poolIdCounter;                       // 池ID计数器
    uint256 private _requestIdCounter;                    // 请求ID计数器
    
    // Events
    event PoolAdded(uint256 indexed pid, address indexed stToken, uint256 poolWeight);
    event PoolUpdated(uint256 indexed pid, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks);
    event Staked(address indexed user, uint256 indexed pid, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 indexed pid, uint256 amount, uint256 requestId, uint256 unlockBlock);
    event UnstakeProcessed(address indexed user, uint256 indexed pid, uint256 amount, uint256 requestId);
    event RewardClaimed(address indexed user, uint256 indexed pid, uint256 amount);
    event MetaNodePerBlockUpdated(uint256 oldRate, uint256 newRate);
    
    // Errors
    error PoolNotExists(uint256 pid);
    error InsufficientBalance(uint256 available, uint256 required);
    error BelowMinDeposit(uint256 amount, uint256 minDeposit);
    error NoPendingReward(address user, uint256 pid);
    error RequestNotFound(uint256 requestId);
    error RequestNotUnlockable(uint256 requestId, uint256 currentBlock, uint256 unlockBlock);
    error TokenNotSupported(address token);
    error InvalidAmount(uint256 amount);
    error AlreadyProcessed(uint256 requestId);
    
    constructor(address _metaNodeToken, uint256 _metaNodePerBlock, uint256 _startBlock) {
        require(_metaNodeToken != address(0), "Invalid MetaNode token address");
        metaNodeToken = ERC20(_metaNodeToken);
        metaNodePerBlock = _metaNodePerBlock;
        startBlock = _startBlock;
        _poolIdCounter = 1;
        _requestIdCounter = 1;
    }
    
    /**
     * @dev 添加质押池 (仅管理员)
     * @param _stTokenAddress 质押代币地址
     * @param _poolWeight 池权重
     * @param _minDepositAmount 最小质押金额
     * @param _unstakeLockedBlocks 解除质押锁定区块数
     */
    function addPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyOwner {
        require(_stTokenAddress != address(0), "Invalid token address");
        require(_poolWeight > 0, "Invalid pool weight");
        require(_minDepositAmount > 0, "Invalid min deposit");
        require(_unstakeLockedBlocks > 0, "Invalid lock period");
        
        uint256 pid = _poolIdCounter++;
        
        pools[pid] = Pool({
            stToken: IERC20(_stTokenAddress),
            poolWeight: _poolWeight,
            lastRewardBlock: block.number > startBlock ? block.number : startBlock,
            accMetaNodePerST: 0,
            stTokenAmount: 0,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlocks,
            exists: true
        });
        
        poolIds.push(pid);
        totalPoolWeight += _poolWeight;
        supportedTokens[_stTokenAddress] = true;
        
        emit PoolAdded(pid, _stTokenAddress, _poolWeight);
    }
    
    /**
     * @dev 更新质押池 (仅管理员)
     */
    function updatePool(
        uint256 _pid,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyOwner {
        if (!pools[_pid].exists) revert PoolNotExists(_pid);
        
        Pool storage pool = pools[_pid];
        
        // 更新总权重
        totalPoolWeight = totalPoolWeight - pool.poolWeight + _poolWeight;
        
        pool.poolWeight = _poolWeight;
        pool.minDepositAmount = _minDepositAmount;
        pool.unstakeLockedBlocks = _unstakeLockedBlocks;
        
        emit PoolUpdated(_pid, _poolWeight, _minDepositAmount, _unstakeLockedBlocks);
    }
    
    /**
     * @dev 更新每区块MetaNode奖励数量 (仅管理员)
     */
    function updateMetaNodePerBlock(uint256 _metaNodePerBlock) external onlyOwner {
        uint256 oldRate = metaNodePerBlock;
        metaNodePerBlock = _metaNodePerBlock;
        emit MetaNodePerBlockUpdated(oldRate, _metaNodePerBlock);
    }
    
    /**
     * @dev 质押代币
     * @param _pid 池ID
     * @param _amount 质押数量
     */
    function stake(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused {
        if (!pools[_pid].exists) revert PoolNotExists(_pid);
        if (_amount == 0) revert InvalidAmount(_amount);
        if (_amount < pools[_pid].minDepositAmount) revert BelowMinDeposit(_amount, pools[_pid].minDepositAmount);
        
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        
        // 转移代币到合约
        uint256 balanceBefore = pool.stToken.balanceOf(address(this));
        pool.stToken.transferFrom(msg.sender, address(this), _amount);
        uint256 actualAmount = pool.stToken.balanceOf(address(this)) - balanceBefore;
        
        if (actualAmount == 0) revert InvalidAmount(actualAmount);
        
        // 更新用户奖励
        _updateUserReward(_pid, msg.sender);
        
        // 更新用户和池数据
        user.stAmount += actualAmount;
        pool.stTokenAmount += actualAmount;
        
        emit Staked(msg.sender, _pid, actualAmount);
    }
    
    /**
     * @dev 请求解除质押
     * @param _pid 池ID
     * @param _amount 解质押数量
     */
    function requestUnstake(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused {
        if (!pools[_pid].exists) revert PoolNotExists(_pid);
        if (_amount == 0) revert InvalidAmount(_amount);
        
        User storage user = users[_pid][msg.sender];
        if (user.stAmount < _amount) revert InsufficientBalance(user.stAmount, _amount);
        
        // 更新用户奖励
        _updateUserReward(_pid, msg.sender);
        
        // 减少用户质押数量
        user.stAmount -= _amount;
        pools[_pid].stTokenAmount -= _amount;
        
        // 创建解质押请求
        uint256 requestId = _requestIdCounter++;
        uint256 unlockBlock = block.number + pools[_pid].unstakeLockedBlocks;
        
        user.requests[requestId] = UnstakeRequest({
            amount: _amount,
            unlockBlock: unlockBlock,
            processed: false
        });
        
        user.requestIds.push(requestId);
        
        emit UnstakeRequested(msg.sender, _pid, _amount, requestId, unlockBlock);
    }
    
    /**
     * @dev 处理解质押请求
     * @param _pid 池ID
     * @param _requestId 请求ID
     */
    function processUnstake(uint256 _pid, uint256 _requestId) external nonReentrant {
        User storage user = users[_pid][msg.sender];
        
        if (user.requests[_requestId].amount == 0) revert RequestNotFound(_requestId);
        if (user.requests[_requestId].processed) revert AlreadyProcessed(_requestId);
        if (block.number < user.requests[_requestId].unlockBlock) {
            revert RequestNotUnlockable(_requestId, block.number, user.requests[_requestId].unlockBlock);
        }
        
        UnstakeRequest storage request = user.requests[_requestId];
        uint256 amount = request.amount;
        
        // 标记为已处理
        request.processed = true;
        
        // 转移代币回用户
        pools[_pid].stToken.transfer(msg.sender, amount);
        
        emit UnstakeProcessed(msg.sender, _pid, amount, _requestId);
    }
    
    /**
     * @dev 领取奖励
     * @param _pid 池ID
     */
    function claimReward(uint256 _pid) external nonReentrant {
        if (!pools[_pid].exists) revert PoolNotExists(_pid);
        
        _updateUserReward(_pid, msg.sender);
        
        User storage user = users[_pid][msg.sender];
        uint256 pending = user.pendingMetaNode;
        
        if (pending == 0) revert NoPendingReward(msg.sender, _pid);
        
        user.pendingMetaNode = 0;
        user.finishedMetaNode += pending;
        
        // 转移奖励代币
        bool success = metaNodeToken.transfer(msg.sender, pending);
        require(success, "Transfer failed");
        
        emit RewardClaimed(msg.sender, _pid, pending);
    }
    
    /**
     * @dev 更新用户奖励
     * @param _pid 池ID
     * @param _user 用户地址
     */
    function _updateUserReward(uint256 _pid, address _user) internal {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][_user];
        
        if (pool.stTokenAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        
        uint256 lastRewardBlock = pool.lastRewardBlock;
        if (block.number <= lastRewardBlock) return;
        
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 metaNodeReward = (multiplier * metaNodePerBlock * pool.poolWeight) / totalPoolWeight;
        uint256 accMetaNodePerShare = pool.accMetaNodePerST + (metaNodeReward * 1e18) / pool.stTokenAmount;
        
        pool.accMetaNodePerST = accMetaNodePerShare;
        pool.lastRewardBlock = block.number;
        
        if (user.stAmount > 0) {
            uint256 pending = (user.stAmount * accMetaNodePerShare) / 1e18 - user.finishedMetaNode - user.pendingMetaNode;
            user.pendingMetaNode += pending;
        }
    }
    
    /**
     * @dev 获取待领取奖励
     * @param _pid 池ID
     * @param _user 用户地址
     * @return 待领取奖励数量
     */
    function getPendingReward(uint256 _pid, address _user) external view returns (uint256) {
        if (!pools[_pid].exists) revert PoolNotExists(_pid);
        
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][_user];
        
        uint256 accMetaNodePerST = pool.accMetaNodePerST;
        
        if (pool.stTokenAmount != 0 && block.number > pool.lastRewardBlock) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 metaNodeReward = (multiplier * metaNodePerBlock * pool.poolWeight) / totalPoolWeight;
            accMetaNodePerST += (metaNodeReward * 1e18) / pool.stTokenAmount;
        }
        
        if (user.stAmount == 0) return user.pendingMetaNode;
        
        return (user.stAmount * accMetaNodePerST) / 1e18 - user.finishedMetaNode - user.pendingMetaNode;
    }
    
    /**
     * @dev 获取用户解质押请求
     * @param _pid 池ID
     * @param _user 用户地址
     * @return requests 解质押请求数组
     */
    function getUserRequests(uint256 _pid, address _user) external view returns (UnstakeRequest[] memory requests) {
        User storage user = users[_pid][_user];
        requests = new UnstakeRequest[](user.requestIds.length);
        
        for (uint256 i = 0; i < user.requestIds.length; i++) {
            requests[i] = user.requests[user.requestIds[i]];
        }
    }
    
    /**
     * @dev 获取所有池ID
     */
    function getPoolIds() external view returns (uint256[] memory) {
        return poolIds;
    }
    
    /**
     * @dev 暂停/恢复特定操作
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 紧急提取代币 (仅管理员)
     */
    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_token);
        bool success = token.transfer(owner(), _amount);
        require(success, "Transfer failed");
    }
}