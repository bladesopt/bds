# Remove the Gradient-Stopping Diagnostics Facility

## Objective

Remove the `output_gradient_stop_diagnostics` option and the
`gradient_stop_diagnostics` output from the repository. The final solver must
contain only the core estimated-gradient stopping algorithm. It must not
contain diagnostic snapshots, diagnostic trace construction, diagnostic-only
branches, or experiment scripts whose purpose is to consume the removed trace.

The following two strict invariants are mandatory after every implementation
stage and at the end of the work:

1. With all acceleration switches disabled,
   `accelerated_bds_options.m` must be behaviorally identical to `bds.m`.
2. With all acceleration switches enabled,
   `accelerated_bds_options.m` must be behaviorally identical to
   `lean_evolved_bds.m`.

“Behaviorally identical” includes objective evaluation points and order,
evaluation counts, returned point and value, histories, stopping decisions,
exit flags, messages, random behavior, and all ordinary solver outputs that
remain after diagnostics removal.

Do not modify the ordinary BDS polling algorithm, the core gradient stopping
criterion, acceleration calculations, public options unrelated to diagnostics,
`grad_hist`, `grad_xhist`, `debug_flag`, or the already revised function-header
comments except where a removed diagnostics option or output is explicitly
mentioned.

## Scope boundary

Remove only the dedicated estimated-gradient diagnostics facility:

- public option `output_gradient_stop_diagnostics`;
- output field `gradient_stop_diagnostics`;
- diagnostic trace schema and record construction;
- diagnostic-only state snapshots and branches;
- defaults and validation for the removed option;
- tests and experiment scripts that require the removed trace;
- documentation that describes the removed facility.

Keep the core estimated-gradient stopping mechanism, including
`use_estimated_gradient_stop`, `grad_window_size`, `grad_tol`,
`use_gradient_reference_consistency`,
`grad_reference_finite_difference_error_tol`,
`grad_reference_relative_tol`, `reference_grad_norm`,
`norm_grad_window`, `previous_gradient`, and the ordinary gradient histories.

Do not delete generic debugging or ordinary history features merely because
they are useful for debugging. The target is the dedicated diagnostics trace,
not the solver’s core state or normal outputs.

## Verification command

Run this command from the repository root after every stage:

```bash
matlab -batch "addpath(genpath(pwd)); report = evalc('verify_bds_acceleration'); disp(report(max(1, end-1200):end));"
```

The command must finish with:

```text
Accelerated BDS options verification passed.
  off: accelerated_bds_options.m == bds.m ...
  on : accelerated_bds_options.m == lean_evolved_bds.m ...
```

For every stage after the core-only gradient-stop regression has been prepared,
also run:

```bash
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
```

Record the original regression result during Stage 0. Every later stage must
leave a runnable core-only replacement; an intentionally failing intermediate
test is not acceptable.

## Stage 0: establish a clean baseline

1. Inspect the working tree and preserve all user changes already present.
2. Run `git diff --check`.
3. Run the strict acceleration verification and the current gradient-stop
   regression.
4. Record the final lines and exit status in the agent’s work log.

No files are changed in this stage.

**Required checkpoint:** both strict invariants pass before proceeding.

## Stage 1: migrate the regression to core-only behavior

Update `tests/verify_gradient_stop_no_extra_evaluations.m` before removing the
solver interface that the old test consumes.

1. Remove the diagnostic-on and diagnostic-off comparison.
2. Preserve the focused assertion that estimated-gradient stopping occurs.
3. Preserve the comparison between explicit final gradient options and the
   solver defaults.
4. Preserve objective-call sequence, `funcCount`, `xhist`, and `fhist`
   accounting assertions.
5. Remove every reference to `output_gradient_stop_diagnostics` and
   `output.gradient_stop_diagnostics`.
6. Rename the test only if its current name becomes materially misleading, and
   update every caller if it is renamed.

**Required checkpoint:** run the migrated core gradient-stop regression,
`git diff --check`, and the strict acceleration verification.

## Stage 2: remove diagnostics from the solver core

Edit `tests/competitors/accelerated_bds_options.m` only in this stage.

1. Remove the function-header option description for
   `output_gradient_stop_diagnostics`.
2. Remove the output description for `gradient_stop_diagnostics`.
3. Remove the local assignment
   `output_gradient_stop_diagnostics = options.output_gradient_stop_diagnostics`.
4. Remove the `gradient_stop_diagnostics = struct(...)` schema.
5. Change the gradient-processing guard from
   `use_estimated_gradient_stop || output_gradient_stop_diagnostics` to
   `use_estimated_gradient_stop`.
6. Delete the diagnostics-only snapshots:
   `reference_initialized_before_iteration`,
   `reference_grad_norm_before`, `reference_grad_norm_after`, and
   `norm_grad_window_before`.
7. Keep the core variables `reference_same_point`,
   `reference_consistency_ratio`, and `reference_candidate_reliable` only
   where they are needed for reference-scale initialization. The consistency
   test must no longer be computed after `reference_grad_norm` has been
   initialized.
8. Delete the entire `if output_gradient_stop_diagnostics` trace-recording
   block.
9. Delete the final block that assigns
   `output.gradient_stop_diagnostics`.
10. Rewrite nearby comments so the core algorithm is readable without any
    mention of diagnostics. Do not change calculations or evaluation order.

**Required checkpoint:** run `git diff --check`, the migrated core gradient-stop
regression, and the strict acceleration verification.

## Stage 3: remove the public option and its defaults

Update the option plumbing without changing any remaining option’s value or
normalization:

1. In `tests/competitors/private/set_accelerated_bds_options.m`, remove the
   default assignment and logical normalization for
   `output_gradient_stop_diagnostics`.
2. In `tests/competitors/private/get_accelerated_bds_default_constant.m`,
   remove the `output_gradient_stop_diagnostics` case.
3. Search all option validation, option documentation, and option-name lists
   for the removed field and delete only the corresponding entries.
4. Confirm that supplying ordinary options still produces the same normalized
   options and solver behavior. The removed option is intentionally no longer
   supported.

**Required checkpoint:** run `git diff --check`, the core gradient-stop
regression, and the strict acceleration verification.

## Stage 4: remove trace-dependent experiment scripts and generated references

Audit `tests/auto_initial_step_size/stopping/` and delete or rewrite files
whose sole purpose is to collect, enrich, replay, or analyze
`gradient_stop_diagnostics` traces. In particular, inspect:

- `run_gradient_stop_concrete_diagnostics.m` and its screen wrapper;
- `run_gradient_reference_controlled_search.m`;
- `run_gradient_no_stop_trace_collection.m` and its screen wrapper;
- `analyze_gradient_no_stop_traces.m`;
- result or investigation documents that describe those traces;
- generated manifests and `.mat` artifacts whose only data source is the
  removed trace.

Delete a file only when it has no remaining non-diagnostic purpose. If a file
contains both diagnostic and independent core experiments, remove the trace
path and preserve the independent experiment. Do not delete generic stopping
benchmark data without checking its consumers.

After this stage, search the full repository for both exact option/output
names and for trace-specific function names. No executable code should refer
to the removed interface.

**Required checkpoint:** run `git diff --check` and the strict acceleration
verification. Run all remaining stopping tests that do not require the
deleted trace.

## Stage 5: delete dedicated documentation and clean remaining references

1. Delete `ACCELERATED_BDS_DIAGNOSTICS_DESIGN.md`; do not archive it in the
   repository.
2. Update `ACCELERATED_BDS_ACCELERATION_REFACTOR_PLAN.md`, interface contracts,
   code-style TODOs, gradient investigation notes, and results documents only
   where they refer to the removed diagnostics interface.
3. Do not remove ordinary uses of the word “debugging” that refer to
   `debug_flag`, printing, invalid-point history, or ordinary histories.
4. Ensure all documentation describes the core gradient stopping mechanism
   without suggesting that a diagnostic trace is returned.

**Required checkpoint:** run `git diff --check` and the strict acceleration
verification.

## Stage 6: repository-wide audit and final acceptance

1. Search the entire repository for:

   ```bash
   rg -n "gradient_stop_diagnostics|output_gradient_stop_diagnostics"
   ```

   No executable code, public option documentation, test, experiment, active
   plan, or historical note may contain either removed name.
2. Search for diagnostic-only snapshots and trace builders by their old field
   names and remove any remaining live references.
3. Run `git diff --check`.
4. Run the strict acceleration verification one final time.
5. Run the replacement core gradient-stop regression and all relevant
   remaining stopping tests.
6. Inspect the final diff manually to confirm that the gradient stopping
   equations, comparison thresholds, ordinary histories, acceleration phases,
   and evaluation order were not changed.
7. After all work and verification records have been captured, delete this
   one-time execution plan. The repository must not retain a plan dedicated to
   a facility that has been completely removed.

## Handoff requirements for the implementing agent

The implementing agent must not claim completion from a textual search alone.
The handoff must include:

- files changed, deleted, or renamed;
- the exact verification commands run after each stage;
- final pass lines for both strict invariants;
- the replacement core gradient-stop regression result;
- confirmation that no historical document containing the removed names was
  retained.

If a strict invariant fails, stop, identify the first failing case, and repair
the minimal cause before proceeding to the next stage.
