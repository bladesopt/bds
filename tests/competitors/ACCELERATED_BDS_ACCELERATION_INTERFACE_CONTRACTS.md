# Acceleration Helper Interface Contracts

Interface refinement for `run_productive_direction_memory_phase` and
`run_post_poll_acceleration_phase`, the two acceleration-phase helpers of
`accelerated_bds_options.m`. This document records the per-field
read/write/lifecycle audit (Stage 1) and the final interface contracts
(Stage 2). No change recorded here may alter computational behaviour; the
strict invariants are:

- all acceleration switches on: `accelerated_bds_options.m` identical to
  `lean_evolved_bds.m`;
- all acceleration switches off: `accelerated_bds_options.m` identical to
  `bds.m`;
- `verify_gradient_stop_no_extra_evaluations` passes.

## Stage 1: field-by-field audit

Categories: **configuration** (read-only, fixed for the whole run or set by
options), **mutable state** (read and possibly written by the phase, owned by
the solver between calls), **phase result** (produced by the phase, consumed
by the caller), **derived** (strictly computable from other data at a more
appropriate layer).

### `run_productive_direction_memory_phase` (current: 17 inputs, 12 outputs)

| Parameter | Source in caller | Read in helper | Written in helper | Consumer after call | Category | Keep? |
|---|---|---|---|---|---|---|
| `fun` | solver argument | yes (`eval_fun`) | no | — | resource | keep (positional) |
| `xbase` | solver base point | yes | yes (on acceptance) | polling, post-poll, `fopt`/`xopt` update | mutable state | keep (state) |
| `fbase` | solver base value | yes | yes (on acceptance) | same as `xbase` | mutable state | keep (state) |
| `alpha_all` | per-block step sizes | only as `mean(alpha_all)` (trial step floor) | no | — | derived | replace by caller-computed scalar `alpha_average` |
| `productive_direction_memory` | solver memory | yes | yes (reorder on success) | polling-loop insertion, post-poll, next iteration | mutable state | keep (state) |
| `use_productive_direction_memory` | `options` | yes (entry guard) | no | — | configuration | keep (config) |
| `nf` | evaluation counter | yes | yes | budget checks, output | mutable state | keep (state) |
| `MaxFunctionEvaluations` | `options` | yes | no | — | configuration | keep (config) |
| `ftarget` | `options` | yes | no | — | configuration | keep (config) |
| `fhist` | history buffer | no (write-only slots) | yes | `output.fhist` | mutable state | keep (state) |
| `xhist` | history buffer | no (write-only slots) | yes | `output.xhist` | mutable state | keep (state) |
| `invalid_points` | history buffer | yes (append) | yes | `output.invalid_points` | mutable state | keep (state) |
| `output_xhist` | `options` | yes | no | — | configuration | keep (config) |
| `target_reached` | termination state | only as own loop state; incoming value provably `false` (see below) | yes | caller termination handling | phase result | keep as pure result |
| `terminate` | termination state | never read; incoming provably `false` | yes (only together with `target_reached`) | polling-loop guard, post-poll guard, loop exit | phase result | keep as pure result |
| `exitflag` | termination state | never read | yes (only `FTARGET_REACHED`, only together with `target_reached`) | output message | phase result | keep as pure result |
| `iteration_improved` | iteration flag | no | yes (set true on acceptance) | none before caller re-derives it | redundant | **drop** (see below) |

Proof obligations for the two non-obvious rows:

- `target_reached`/`terminate` incoming values: `target_reached = true` is
  always set together with `terminate = true` (initial check, both helpers),
  and the iteration loop breaks at its end whenever `terminate` is true. The
  pre-poll call is the first statement of the iteration body, so both flags
  are `false` at every call. The helper reads `target_reached` only to break
  its own loop after it set the flag itself.
- `iteration_improved`: the helper only ever sets it `true`, and only after
  accepting `fnew < fbase`, i.e. after strictly decreasing `fbase`. Between
  the pre-poll call and the line `if fbase < fbase_iteration_start,
  iteration_improved = true; end` there is no consumer of
  `iteration_improved`, and that line re-derives exactly the same fact
  (strict decrease of `fbase` since iteration start). The incoming value is
  always `false` (initialized at the top of the iteration body). Hence the
  parameter is fully redundant and is removed from the interface.

### `run_post_poll_acceleration_phase` (current: 22 inputs, 12 outputs)

| Parameter | Source in caller | Read in helper | Written in helper | Consumer after call | Category | Keep? |
|---|---|---|---|---|---|---|
| `fun` | solver argument | yes (`eval_fun`) | no | — | resource | keep (positional) |
| `xbase` | solver base point | yes | yes (on acceptance) | `fopt`/`xopt` update, gradient stop, output | mutable state | keep (state) |
| `fbase` | solver base value | yes | yes (on acceptance) | same as `xbase` | mutable state | keep (state) |
| `iteration_step` | `xbase - xbase_iteration_start` | yes (pattern direction) | no | — | per-iteration input | keep (positional) |
| `iteration_step_norm` | `norm(iteration_step)` | yes (pattern step, normalization) | no | — | derived | **drop**; compute `norm(iteration_step)` inside the helper |
| `momentum` | solver momentum vector | yes | yes (every time the phase is entered with momentum on) | next iteration | mutable state | keep (state, post-poll only) |
| `momentum_decay` | `options` | yes | no | — | configuration | keep (config) |
| `productive_direction_memory` | solver memory | yes | yes (insert on success) | polling loop, pre-poll, next iteration | mutable state | keep (state) |
| `productive_direction_memory_size` | `options` | yes | no | — | configuration | keep (config) |
| `alpha_tol` | `options.StepTolerance` | only as `max(alpha_tol)` | no | — | derived | replace by scalar `step_floor = max(alpha_tol)`, precomputed once |
| `use_iteration_pattern_step` | `options` | yes | no | — | configuration | keep (config) |
| `use_momentum_extrapolation` | `options` | yes | no | — | configuration | keep (config) |
| `use_productive_direction_memory` | `options` | yes (memory insertion guard) | no | — | configuration | keep (config) |
| `nf` | evaluation counter | yes | yes | budget checks, output | mutable state | keep (state) |
| `MaxFunctionEvaluations` | `options` | yes | no | — | configuration | keep (config) |
| `ftarget` | `options` | yes | no | — | configuration | keep (config) |
| `fhist` | history buffer | no (write-only slots) | yes | `output.fhist` | mutable state | keep (state) |
| `xhist` | history buffer | no (write-only slots) | yes | `output.xhist` | mutable state | keep (state) |
| `invalid_points` | history buffer | yes (append) | yes | `output.invalid_points` | mutable state | keep (state) |
| `output_xhist` | `options` | yes | no | — | configuration | keep (config) |
| `target_reached` | termination state | only as own search state; incoming provably `false` (entry guard requires `~terminate`, and `target_reached` implies `terminate`) | yes | caller termination handling | phase result | keep as pure result |
| `terminate` | termination state | never read | yes (only together with `target_reached`) | loop exit, stopping checks | phase result | keep as pure result |
| `exitflag` | termination state | never read | yes (only `FTARGET_REACHED`, only together with `target_reached`) | output message | phase result | keep as pure result |
| `post_poll_acceleration_succeeded` (output) | — | — | yes | objective-change stop guard, gradient-estimation guard | phase result | keep (result) |

The entry guard (`~terminate && iteration_improved && iteration_step_norm >
max(alpha_tol) && nf < MaxFunctionEvaluations && (use_iteration_pattern_step
|| use_momentum_extrapolation)`) stays at the call site, so the main solver
keeps the phase ordering visible; the helper is only ever called when the
phase is entered.

## Stage 2: final interface contracts

Three explicit layers, following the shape of `inner_direct_search` (narrow
options/config in, state threaded through, results collected in a struct):

```matlab
[state, result] = run_productive_direction_memory_phase(fun, state, config, alpha_average);
[state, result] = run_post_poll_acceleration_phase(fun, state, config, iteration_step);
```

### `config` — read-only acceleration configuration

Built once before the main loop from `options` and never mutated. Contains
only acceleration-phase settings plus the evaluation limits both phases
share; it is not the public `options` structure.

| Field | Meaning | Used by |
|---|---|---|
| `use_productive_direction_memory` | enable retained-direction memory | both phases |
| `use_iteration_pattern_step` | enable post-poll pattern step | post-poll |
| `use_momentum_extrapolation` | enable momentum update/search | post-poll |
| `momentum_decay` | momentum update weight | post-poll |
| `productive_direction_memory_size` | memory capacity | post-poll (insertion) |
| `step_floor` | `max(alpha_tol)`, precomputed once | post-poll |
| `MaxFunctionEvaluations` | evaluation budget | both phases |
| `ftarget` | target function value | both phases |
| `output_xhist` | whether point history is recorded | both phases |

Each helper reads only its documented subset; ownership is listed above
rather than split into two structs because the shared evaluation limits make
one small flat struct simpler than two overlapping ones.

### `state` — mutable solver/evaluation state

Packed immediately before each call and unpacked immediately after, so the
caller shows exactly which variables the phase may change. Fixed field set;
helpers never add fields.

| Field | Ownership |
|---|---|
| `xbase`, `fbase` | base point and value; updated on accepted improvement |
| `nf`, `fhist`, `xhist`, `invalid_points` | evaluation bookkeeping; appended by every evaluation the phase performs |
| `productive_direction_memory` | retained-direction memory; reordered (pre-poll) or inserted into (post-poll) |
| `momentum` | momentum vector; present only in the post-poll call, updated on every entry with momentum enabled |

### Per-iteration positional inputs

- `alpha_average` = `mean(alpha_all)`: computed by the caller each iteration
  (it changes as block step sizes shrink/expand); the helper needs only this
  scalar, not the per-block vector.
- `iteration_step` = `xbase - xbase_iteration_start`: the net displacement of
  the iteration; the helper computes `norm(iteration_step)` internally.

### `result` — phase result

Pure output; the helper never reads the incoming termination state because
that state is provably `false`/unset at every call site (see audit).

| Field | Meaning |
|---|---|
| `succeeded` | post-poll only: `post_poll_acceleration_succeeded` (an acceleration candidate was accepted) |
| `target_reached` | the phase evaluated a point with `fnew <= ftarget` |

The pre-poll result carries only `target_reached`; whether a retained
direction was accepted is already visible in the updated base point.

The caller applies the termination update explicitly and identically after
each call, preserving the termination/exitflag precedence of the original
code:

```matlab
if result.target_reached
    terminate = true;
    exitflag = get_exitflag("FTARGET_REACHED");
end
```

`exitflag` no longer passes through the helpers at all: they only ever wrote
`FTARGET_REACHED` (never read the incoming value), so ownership of the
termination update stays visibly in the main solver.

### Why this is simpler than the positional interface

- 17/22 positional arguments collapse to 4 per call, with every remaining
  argument a different lifecycle layer (resource / mutable state / read-only
  config / per-iteration input) instead of an undifferentiated list.
- `iteration_improved`, `iteration_step_norm`, the `alpha_all` vector and the
  `alpha_tol` vector leave the interface entirely; each is provably redundant
  or derivable (audit above), not merely moved into a struct.
- The termination triple is no longer threaded through both helpers as
  in/out parameters; the helpers return a single fact (`target_reached`) and
  the solver applies it, keeping exitflag precedence in one visible place.
- Mutation ownership is explicit at the call site: the fields packed into
  `state` are exactly the variables the phase may change, and nothing else
  in the solver workspace is reachable by the helpers.

## Behaviour preserved (checked by the strict invariants)

Pre-poll: memory list order; trial step `max(alpha_average, stored_step)`;
candidate evaluation order; acceptance comparison; target checks; at most
two extrapolation evaluations; memory reordering; `nf`/`fhist`/`xhist`/
`invalid_points` bookkeeping; termination and exitflag precedence.

Post-poll: entry-guard timing and location; pattern direction/step;
momentum update, decay and normalization order; factors `[1, 2, 4]`; pattern
search before momentum search; no momentum search after a successful
pattern; suppression of reevaluating an identical failed pattern point;
target and budget checks; history and invalid-point recording;
productive-memory update on success; `post_poll_acceleration_succeeded`;
termination and exitflag precedence.

## Verification log

All runs on this machine via
`matlab -batch "addpath(genpath(pwd)); <check>"`. "accel" =
`verify_bds_acceleration`, "gradstop" =
`verify_gradient_stop_no_extra_evaluations`.

- Stage 0 baseline (unmodified tree): accel passed, gradstop passed.
- Stage 3 (pre-poll struct interface, no data removed): accel passed,
  gradstop passed.
- Stage 4 (post-poll struct interface, no data removed): accel passed,
  gradstop passed.
- Stage 5 step 1 (`alpha_all` -> `alpha_average`, `alpha_tol` ->
  `step_floor`): accel passed.
- Stage 5 step 2 (`iteration_step_norm` computed inside the post-poll
  helper): accel passed.
- Stage 5 step 3 (termination triple demoted to pure phase result,
  `iteration_improved` removed from the pre-poll interface): accel passed,
  gradstop passed.
- Stage 5 step 4 (premature initializations): no change required —
  `post_poll_acceleration_succeeded = false` and `iteration_improved = false`
  at the top of the iteration body are still needed (the post-poll guard may
  skip the phase, and the polling path consumes the flags).
- Follow-up cleanup: two success flags with no remaining reader were deleted,
  and the unused pre-poll `result.succeeded` field was removed with them. The
  reference-consistency test was rewritten without snapshot variables. Accel
  passed, gradstop passed.
- Stage 6 (helper headers and call-site comments): accel passed, gradstop
  passed.
- Stage 7 final acceptance: accel passed, gradstop passed,
  `git diff --check` clean.

Warnings during the runs are pre-existing test-harness messages (expected
failed function evaluations in test problems, Java package notices), not
regressions introduced by this refactor.
