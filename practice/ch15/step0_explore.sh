#!/bin/bash
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter15
ls -R "$B" | head -50
for f in $(find "$B/docker_setup_scripts" -type f | head -20); do echo "===== $f"; cat "$f"; done
ls ~/k136_venv/bin | head; ~/k136_venv/bin/python -c "import numpy, matplotlib; print(numpy.__version__, matplotlib.__version__)" || true
