#!/usr/bin/env bash
set -u

repo_dir=/home/lhtian97/Work/bds
status_dir="$repo_dir/tests/testdata/gradient_no_stop_trace_status"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="$status_dir/full_${timestamp}.log"
exit_file="$status_dir/full_${timestamp}.exit_code"
mkdir -p "$status_dir"
{
    printf 'log_file=%s\n' "$log_file"
    printf 'exit_file=%s\n' "$exit_file"
} > "$status_dir/latest_launch.txt"

cd "$repo_dir" || exit 1
matlab -batch "addpath('$repo_dir/tests/auto_initial_step_size/stopping'); run_gradient_no_stop_trace_collection" \
    > "$log_file" 2>&1
status=$?
printf '%d\n' "$status" > "$exit_file"
exit "$status"
