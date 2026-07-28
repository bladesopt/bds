#!/usr/bin/env bash
set -u

repo_dir=/home/lhtian97/Work/bds
status_dir="$repo_dir/tests/testdata/ten_solver_screen_runtime"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="$status_dir/ten_solver_full_${timestamp}.log"
exit_file="$status_dir/ten_solver_full_${timestamp}.exit"
complete_file="$status_dir/ten_solver_full_${timestamp}.complete"
failed_file="$status_dir/ten_solver_full_${timestamp}.failed"
resume_root="${1:-}"

mkdir -p "$status_dir"
{
    printf 'timestamp=%s\n' "$timestamp"
    printf 'log_file=%s\n' "$log_file"
    printf 'exit_file=%s\n' "$exit_file"
    printf 'complete_file=%s\n' "$complete_file"
    printf 'failed_file=%s\n' "$failed_file"
    printf 'resume_root=%s\n' "$resume_root"
} > "$status_dir/latest_launch.txt"

cd "$repo_dir" || exit 1
matlab -batch "addpath('$repo_dir/tests/auto_initial_step_size'); manifest=run_ten_solver_500n_benchmark('full', [], '$resume_root'); assert(strcmp(manifest.status,'COMPLETE')); assert(isequal(manifest.n_runs,[1,5,5,5,5,5,5,5,5,5]));" \
    > "$log_file" 2>&1
exit_code=$?
printf '%d\n' "$exit_code" > "$exit_file"

if [ "$exit_code" -eq 0 ]; then
    touch "$complete_file"
else
    touch "$failed_file"
fi

exit "$exit_code"
