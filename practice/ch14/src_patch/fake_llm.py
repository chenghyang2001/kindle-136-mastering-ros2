#!/usr/bin/env python3
"""本演練新增：規則式假 LLM，取代 ChatOpenAI，不需要任何金鑰。

行為模仿「會用工具的 OpenAI 模型」：
  1. 收到人類指令 → 用關鍵字判斷要呼叫哪個工具，回傳帶 tool_calls 的 AIMessage
  2. 收到工具結果（ToolMessage）→ 回傳最終文字答案，讓 AgentExecutor 結束
這樣 create_openai_tools_agent / AgentExecutor 的整條工具呼叫流程都會真的跑過。
"""
import re
import uuid
from typing import Any, List, Optional

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, ToolMessage
from langchain_core.outputs import ChatGeneration, ChatResult

_NUM = re.compile(r"-?\d+(?:\.\d+)?")


def _first_number(text: str, default: float) -> float:
    found = _NUM.search(text)
    return float(found.group()) if found else default


def plan_tool_call(text: str) -> Optional[dict]:
    """把一句指令轉成 (工具名稱, 參數)；認不得就回 None。"""
    lower = text.lower()
    if any(k in lower for k in ("forward", "前進", "往前", "向前")):
        return {"name": "move_forward", "args": {"distance": _first_number(text, 2.0)}}
    if any(k in lower for k in ("rotate", "turn", "轉")):
        return {"name": "rotate", "args": {"angle": _first_number(text, 90.0)}}
    if any(k in lower for k in ("pose", "position", "where", "位置", "在哪")):
        return {"name": "get_pose", "args": {}}
    return None


class RuleBasedFakeToolLLM(BaseChatModel):
    """不連網的假聊天模型；bind(tools=...) 傳進來的工具定義直接忽略。"""

    @property
    def _llm_type(self) -> str:
        return "rule-based-fake-tool-llm"

    def _generate(self, messages: List[BaseMessage], stop: Optional[List[str]] = None,
                  run_manager: Any = None, **kwargs: Any) -> ChatResult:
        last = messages[-1] if messages else None
        if isinstance(last, ToolMessage):
            reply = AIMessage(content=f"Done. Tool result: {last.content}")
        else:
            human = next((m for m in reversed(messages) if isinstance(m, HumanMessage)), None)
            text = str(human.content) if human is not None else ""
            call = plan_tool_call(text)
            if call is None:
                reply = AIMessage(content="I can only move_forward, rotate, or get_pose.")
            else:
                call["id"] = f"call_{uuid.uuid4().hex[:8]}"
                reply = AIMessage(content="", tool_calls=[call])
        return ChatResult(generations=[ChatGeneration(message=reply)])


if __name__ == "__main__":
    # 冒煙測試：不需要 ROS
    assert plan_tool_call("Move the turtle forward 2 units")["args"] == {"distance": 2.0}
    assert plan_tool_call("往前走 3")["name"] == "move_forward"
    assert plan_tool_call("hello") is None
    out = RuleBasedFakeToolLLM().invoke("rotate 45")
    assert out.tool_calls[0]["name"] == "rotate"
    print("FAKE_LLM_SELFTEST_OK")
