#!/bin/bash
# Double-clickable stopper for PrimeEye. Kills the running process, which fully releases
# the camera (handy before closing the lid). Safe to run when nothing is running.
set -uo pipefail

if pkill -f "PrimeEye.app/Contents/MacOS/PrimeEye"; then
  echo "Stopped PrimeEye (camera released)."
else
  echo "PrimeEye was not running."
fi
