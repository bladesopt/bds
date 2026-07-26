#!/usr/bin/env bash
set -euo pipefail

cd /home/lhtian97/Work/bds
status_dir="tests/testdata/gradient_stop_final_comparison_status"
mkdir -p "$status_dir"
stamp=$(date +%Y%m%d_%H%M%S)
log_file="$status_dir/full_${stamp}.log"
exit_file="$status_dir/full_${stamp}.exit"

set +e
matlab -batch "addpath('/home/lhtian97/Work/bds/tests/auto_initial_step_size/stopping'); run_gradient_stop_final_comparison" \
    >"$log_file" 2>&1
exit_code=$?
set -e
printf '%s\n' "$exit_code" >"$exit_file"
exit "$exit_code"
