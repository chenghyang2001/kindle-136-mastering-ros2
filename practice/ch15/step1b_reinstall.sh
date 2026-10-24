#!/bin/bash
set -eo pipefail
source ~/k136_venv/bin/activate
cd /tmp
python -m pip install -q gymnasium
python -c "import gymnasium as g; e=g.make(\"CartPole-v1\"); print(\"make OK\", g.__version__, e.observation_space.shape)"
