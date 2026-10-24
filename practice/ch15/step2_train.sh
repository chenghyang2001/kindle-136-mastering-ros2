#!/bin/bash
set -eo pipefail
source ~/k136_venv/bin/activate
timeout 110 python cartpole_qlearning.py --episodes 600 --seed 0 --out results
