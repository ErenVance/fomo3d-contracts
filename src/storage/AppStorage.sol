// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

enum RoundStatus {
    NotStarted, // 轮次已创建但无人购买
    Active, // 倒计时进行中
    Ended // 倒计时结束，等待结算
}

struct RoundInfo {
    RoundStatus status;
    bool isPrizePaid;
    uint64 startTime;
    uint64 endTime; // 倒计时截止
    uint256 totalShares;
    uint256 earningsPerShare; // EPS 累加器
    uint256 epsRemainder; // EPS 除法余数
    uint256 grandPrizePool; // 大奖池
    uint256 dividendPool; // 分红池（追踪已分配总量）
}

struct PlayerInfo {
    uint256 earningsPerShare; // 玩家 EPS 快照
    uint256 accumulatedEarnings; // 已结算但未领取的分红
    uint32 roundNumber; // 玩家所在轮次
    uint256 shares; // 持有的 share 数量
    bool hasExited; // 是否已退出当前轮次
}

/// @title AppStorage — Fomo3D 共享存储
/// @dev 所有 facet 通过 LibAppStorage.appStorage() 访问同一份存储
struct AppStorage {
    bool initialized;
    bool paused;
    // === 代币 ===
    address burnToken; // 用户销毁的 ERC20 代币地址
    address burnAddress; // 代币销毁目标地址（默认 0xdead）
    // === 费用 ===
    address devAddress; // dev 手续费接收地址
    uint16 devFeeBps; // 500 = 5%
    // === 倒计时 ===
    uint64 initialCountdown; // 初始倒计时（秒）
    uint64 countdownExtension; // 每次购买延长（秒）
    uint64 maxCountdown; // 最大倒计时上限（秒）
    // === 池子分配（basis points, 10000 = 100%）===
    uint16 injectionPoolBps; // 5000 = 50% 新 BNB → 注入池（立即分配）
    uint16 pendingPoolBps; // 5000 = 50% 新 BNB → 待注入池（下一轮用）
    uint16 dividendBps; // 5000 = 50% 注入池 → 分红
    uint16 grandPrizeBps; // 5000 = 50% 注入池 → 大奖
    // === 惩罚 ===
    uint16 unexitedPenaltyBps; // 5000 = 50% 轮次结束未退出惩罚
    // === 大奖分配 ===
    uint16 grandTop1Bps; // 5500 = 55% 最后一个买家
    uint16 grandOthersBps; // 500 = 5% 其余 9 个买家
    // === 游戏状态 ===
    uint32 roundNumber;
    uint256 trackedBalance; // BNB 差值检测基准
    uint256 pendingPool; // 下一轮可用 BNB
    uint256 nextRoundCarryover; // 未退出惩罚 → 下一轮大奖
    // === 价格 ===
    uint256 sharePrice; // 每个 share 需要多少 token（整数倍率，如 1000 = 1000 token/share）
    // === 统计 ===
    uint256 totalBurnedTokens;
    // === 映射 ===
    mapping(address => PlayerInfo) players;
    mapping(uint32 => RoundInfo) rounds;
    // === Pull 模式提现 ===
    mapping(address => uint256) pendingWithdrawals; // 大奖 pull 模式待领取
    // === lastBuyers 独立 mapping（不在 RoundInfo 内，方便扩展）===
    mapping(uint32 => address[10]) roundLastBuyers; // [0]=最近买家, [9]=最远
}

library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("fomo3d.app.storage");

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
