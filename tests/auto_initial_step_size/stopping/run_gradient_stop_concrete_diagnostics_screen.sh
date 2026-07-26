#!/usr/bin/env bash
set -u

cd /home/lhtian97/Work/bds || exit 1
log_file=tests/testdata/gradient_stop_concrete_diagnostics_screen.log
exit_file=tests/testdata/gradient_stop_concrete_diagnostics_screen.exit
rm -f "$exit_file"
matlab -batch "addpath('tests/auto_initial_step_size/stopping'); run_gradient_stop_concrete_diagnostics" \
    >"$log_file" 2>&1
status=$?
printf '%d\n' "$status" >"$exit_file"
exit "$status"
