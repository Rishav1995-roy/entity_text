#!/usr/bin/env bash
# Assembles doc/demo.gif from the frames written by capture_demo_test.dart.
set -euo pipefail
cd "$(dirname "$0")/.."
ffmpeg -y -loglevel error -framerate 30 -i build/demo_frames/f_%04d.png \
  -vf "fps=15,scale=400:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 ../doc/demo.gif
ls -l ../doc/demo.gif
