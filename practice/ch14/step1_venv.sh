#!/bin/bash
# 第 1 步：建 ~/k136_venv 並安裝書上用的 langchain 套件（不設任何金鑰）
# 書上程式用 langchain.agents.AgentExecutor / create_openai_tools_agent，
# 這兩個在 langchain 1.x 已移除（搬到 langchain-classic），所以鎖 <1.0
set -eo pipefail
dpkg -s python3.12-venv >/dev/null 2>&1 || sudo apt-get install -y python3.12-venv
# 上次沒裝 python3-venv 留下的半成品 venv（沒有 pip）先刪掉
[ -x ~/k136_venv/bin/pip ] || rm -rf ~/k136_venv
if [ ! -x ~/k136_venv/bin/python ]; then
  python3 -m venv --system-site-packages ~/k136_venv
fi
# 第一次用寬鬆範圍 "<1.0" 時 pip 卡在解析＋斷線 10 分鐘沒裝進任何東西，改鎖 0.3 系列小版本
~/k136_venv/bin/python -m pip install --progress-bar off --timeout 30 --retries 10 \
  "langchain~=0.3.27" "langchain-openai~=0.3.30" "langchain-core~=0.3.70" python-dotenv
~/k136_venv/bin/python -m pip list 2>/dev/null | grep -i -E "langchain|openai|dotenv"
~/k136_venv/bin/python -c "from langchain.agents import AgentExecutor, create_openai_tools_agent; from langchain_openai import ChatOpenAI; print('IMPORT_OK')"
echo "STEP1_DONE"
