#!/bin/bash
set -eo pipefail
source ~/k136_venv/bin/activate
python -m pip install -q gymnasium
python -c "import gymnasium as gym; print(\"gymnasium\", gym.__version__); e=gym.make(\"CartPole-v1\"); print(e.observation_space, e.action_space)"
