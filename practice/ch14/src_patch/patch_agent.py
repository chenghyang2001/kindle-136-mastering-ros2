#!/usr/bin/env python3
"""本演練改：把工作區複製檔 ros2_ai_agent_turtlesim.py 的 ChatOpenAI 換成「可切換」。

沒有 OPENAI_API_KEY（或 LLM_BACKEND=fake）→ 用 fake_llm.RuleBasedFakeToolLLM
有金鑰且 LLM_BACKEND=openai → 照書上用 ChatOpenAI(gpt-4o-mini)
用法：python3 patch_agent.py <agent.py 路徑>
"""
import sys
from pathlib import Path

OLD = '        self.llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)\n'
NEW = '''        # 本演練改：沒有金鑰時改用規則式假 LLM（見 fake_llm.py），工具呼叫流程不變
        backend = os.environ.get("LLM_BACKEND", "auto")
        has_key = bool(os.environ.get("OPENAI_API_KEY"))
        if backend == "openai" or (backend == "auto" and has_key):
            self.llm = ChatOpenAI(model="gpt-4o-mini", temperature=0)
        else:
            from ros2_basic_agent.fake_llm import RuleBasedFakeToolLLM
            self.llm = RuleBasedFakeToolLLM()
        self.get_logger().info(f"LLM backend: {type(self.llm).__name__}")
'''
MARK = "本演練改"


def main():
    if len(sys.argv) != 2:
        print("用法：patch_agent.py <ros2_ai_agent_turtlesim.py>", file=sys.stderr)
        sys.exit(2)
    target = Path(sys.argv[1])
    try:
        src = target.read_text(encoding="utf-8")
    except OSError as e:
        print(f"錯誤：讀不到 {target}：{e}", file=sys.stderr)
        sys.exit(1)
    if MARK in src:
        print("ALREADY_PATCHED")
        return
    if OLD not in src:
        print("錯誤：找不到 ChatOpenAI 那一行，書本程式可能改版了", file=sys.stderr)
        sys.exit(1)
    target.write_text(src.replace(OLD, NEW), encoding="utf-8")
    print("PATCHED")


if __name__ == "__main__":
    main()
