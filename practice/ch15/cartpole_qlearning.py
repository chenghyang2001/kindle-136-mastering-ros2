"""CartPole 表格式 Q-learning（K136 第 15 章快速演練）

書上用 Isaac Lab + PPO（GPU 平行模擬）；本機沒有 NVIDIA GPU，
改用 gymnasium CartPole + 把連續狀態離散化成格子的 Q-table，
走一樣的 RL 流程：環境 → 觀測 → 策略選動作 → 獎勵 → 更新策略。
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

try:
    import gymnasium as gym
except ImportError:
    print("錯誤：找不到 gymnasium，請先在 ~/k136_venv 安裝", file=sys.stderr)
    sys.exit(1)

import matplotlib
matplotlib.use("Agg")  # 無頭環境，不開視窗
import matplotlib.pyplot as plt

# 位置與速度對平衡幫助小，用少一點格子；角度與角速度最關鍵，切細一點
BINS = (1, 1, 8, 12)
# 速度類觀測理論上無界，裁到實際常見範圍才好分格
LOWER = np.array([-2.4, -3.0, -0.21, -3.5])
UPPER = np.array([2.4, 3.0, 0.21, 3.5])


def discretize(obs):
    """把 4 維連續觀測轉成 Q-table 索引。"""
    ratio = (np.clip(obs, LOWER, UPPER) - LOWER) / (UPPER - LOWER)
    idx = (ratio * np.array(BINS)).astype(int)
    return tuple(np.minimum(idx, np.array(BINS) - 1))


def schedule(episode, minimum, decay):
    """探索率與學習率都隨回合數遞減（前期多探索、後期收斂）。"""
    return max(minimum, min(1.0, 1.0 - np.log10((episode + 1) / decay)))


def train(episodes, seed, gamma=0.99):
    env = gym.make("CartPole-v1")
    rng = np.random.default_rng(seed)
    q_table = np.zeros(BINS + (env.action_space.n,))
    lengths = []
    obs, _ = env.reset(seed=seed)
    for ep in range(episodes):
        if ep > 0:
            obs, _ = env.reset()
        state = discretize(obs)
        epsilon = schedule(ep, 0.01, 25)
        alpha = schedule(ep, 0.1, 25)
        steps, done = 0, False
        while not done:
            if rng.random() < epsilon:
                action = int(env.action_space.sample())
            else:
                action = int(np.argmax(q_table[state]))
            obs, reward, terminated, truncated, _ = env.step(action)
            next_state = discretize(obs)
            # 倒下（terminated）沒有未來回報；時間到（truncated）仍要 bootstrap
            target = reward + (0.0 if terminated else gamma * np.max(q_table[next_state]))
            q_table[state + (action,)] += alpha * (target - q_table[state + (action,)])
            state, steps = next_state, steps + 1
            done = terminated or truncated
        lengths.append(steps)
    env.close()
    return np.array(lengths), q_table


def evaluate(q_table, n, seed):
    """關掉探索，純貪婪策略跑 n 回合。"""
    env = gym.make("CartPole-v1")
    results = []
    for i in range(n):
        obs, _ = env.reset(seed=seed + 1000 + i)
        steps, done = 0, False
        while not done:
            obs, _, terminated, truncated, _ = env.step(int(np.argmax(q_table[discretize(obs)])))
            steps += 1
            done = terminated or truncated
        results.append(steps)
    env.close()
    return results


def plot(lengths, out_png):
    window = 50
    moving = np.convolve(lengths, np.ones(window) / window, mode="valid")
    fig, ax = plt.subplots(figsize=(9, 4.5))
    ax.plot(lengths, color="#9bb7d4", linewidth=0.8, label="episode length")
    ax.plot(np.arange(window - 1, len(lengths)), moving, color="#1f4e79",
            linewidth=2, label=f"{window}-episode moving average")
    ax.axhline(500, color="#c0504d", linestyle="--", linewidth=1, label="max (500)")
    ax.set_xlabel("Episode")
    ax.set_ylabel("Steps balanced")
    ax.set_title("CartPole-v1 tabular Q-learning")
    ax.legend(loc="upper left")
    fig.tight_layout()
    fig.savefig(out_png, dpi=120)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--episodes", type=int, default=600)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--out", default="results")
    args = parser.parse_args()
    if args.episodes < 100:
        print("錯誤：episodes 至少 100 才看得出學習曲線", file=sys.stderr)
        sys.exit(1)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        lengths, q_table = train(args.episodes, args.seed)
        evals = evaluate(q_table, 20, args.seed)
        plot(lengths, out_dir / "learning_curve.png")
    except Exception as exc:  # 快速演練：失敗時印出完整原因再結束
        print(f"錯誤：訓練失敗 {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
    summary = {
        "episodes": args.episodes,
        "first_100_avg": float(lengths[:100].mean()),
        "last_100_avg": float(lengths[-100:].mean()),
        "greedy_eval_20_avg": float(np.mean(evals)),
        "greedy_eval_20": evals,
        "q_table_shape": list(q_table.shape),
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    # 冒煙驗證：後段平均應明顯比前段長
    assert summary["last_100_avg"] > 2 * summary["first_100_avg"], "學習沒有明顯進步"
    print("OK：平均回合長度明顯變長")


if __name__ == "__main__":
    main()
