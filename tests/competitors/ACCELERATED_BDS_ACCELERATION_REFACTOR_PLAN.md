# Accelerated BDS Acceleration Refactor Plan

Status: proposed execution plan. The plan is intended to be carried out after
review, with strict behavioural verification after every implementation step.

## Objective

Move the three acceleration mechanisms out of the main iteration body of
`accelerated_bds_options.m` while preserving every numerical and observable
behavioural detail.

The target structure is:

```text
main solver iteration
    ├── productive-direction memory phase
    ├── regular BDS polling phase
    └── post-poll acceleration phase
            ├── iteration pattern step
            └── momentum extrapolation
```

The main solver should retain iteration-level orchestration, ordinary BDS
polling, shared solver state, and termination ordering. The acceleration
details should live in private helper functions.

## Non-negotiable invariants

Every implementation step must pass both strict equivalence targets before the
next step begins. Matching only the final point or objective value is not
sufficient.

### Acceleration switches enabled

With

```matlab
use_productive_direction_memory = true
use_iteration_pattern_step = true
use_momentum_extrapolation = true
```

`accelerated_bds_options.m` must remain exactly equivalent to
`lean_evolved_bds.m` for the default algorithm and for explicit
`Algorithm = "cbds"`.

### Acceleration switches disabled

With

```matlab
use_productive_direction_memory = false
use_iteration_pattern_step = false
use_momentum_extrapolation = false
```

`accelerated_bds_options.m` must remain exactly equivalent to `bds.m` for the
same explicit solver options and all supported algorithms covered by the
strict checker.

### Required checker after every step

Run:

```matlab
addpath(genpath(pwd));
verify_bds_acceleration
```

This checker must pass after the baseline and after every refactor commit or
logical implementation step. Warnings from test problems do not count as
failures. Any MATLAB error or `iseqiv` failure blocks the next step.

Focused regression checks should also be run whenever a step touches gradient
stopping bookkeeping or objective-evaluation bookkeeping:

```matlab
addpath(genpath(pwd));
verify_gradient_stop_no_extra_evaluations
```

## Scope and non-goals

This plan concerns code structure only. It does not authorize changing the
acceleration formulas, candidate ordering, acceptance inequalities, memory
ordering, momentum initialization, function-evaluation accounting, random
stream use, stopping priority, public option names, or output semantics.

The recent function-header comment work is not discarded. Public option and
output descriptions remain useful. Some local implementation comments may
move with the code into private helpers and should be reviewed after the
refactor rather than rewritten in parallel with it.

The plan does not introduce diagnostics for any mechanism.

## Stage 0: Baseline and working-tree inventory

Before editing implementation code:

1. Record the current `git status` and preserve all user changes.
2. Read the complete current iteration body and all private helpers called by
   the acceleration phases.
3. Run `verify_bds_acceleration` and record that both strict suites pass.
4. Run `verify_gradient_stop_no_extra_evaluations`.
5. Identify every variable read or written by each acceleration phase,
   including histories, function-evaluation counters, termination flags,
   momentum state, and productive-direction memory.

Acceptance gate: the baseline is known to pass, and the state inventory is
complete enough to define helper contracts without guessing.

## Stage 1: Define phase contracts without changing behaviour

Write down the input/output contract for each phase before moving code.

### Pre-poll productive-direction memory phase

Candidate helper:

```text
run_productive_direction_memory_phase
```

It owns the pre-poll search over retained directions, candidate evaluation,
accepted-direction extrapolation, memory reordering, and the phase success
flag. It must preserve:

- list order and duplicate-direction handling;
- the trial step `max(mean(alpha_all), stored_step)`;
- candidate acceptance and target checks;
- at most two extrapolation evaluations after a productive candidate;
- function-history and invalid-point recording;
- function-evaluation budget handling;
- termination state and exitflag precedence.

### Post-poll acceleration phase

Candidate helper:

```text
run_post_poll_acceleration_phase
```

It owns pattern-direction construction, pattern-step construction, momentum
update and normalization, pattern candidates, momentum candidates, failed
pattern-candidate suppression, accepted acceleration updates, and memory
insertion. It must preserve:

- the condition that the phase is entered only after an improving iteration;
- the `max(alpha_tol)` displacement threshold;
- the momentum update order and norm threshold;
- pattern search before momentum search;
- momentum search only when pattern search does not improve;
- candidate factors `[1, 2, 4]` and opportunistic stopping;
- the rule preventing reevaluation of an identical failed pattern candidate;
- target checks, evaluation accounting, histories, and exitflag handling.

Acceptance gate: contracts are documented in the plan or an accompanying
implementation note, and the strict checker still passes because no solver
behaviour has changed.

## Stage 2: Extract the pre-poll memory phase

Move only the productive-direction memory block into a private helper. Keep the
call site and all state updates explicit enough to audit. Do not combine this
step with pattern/momentum extraction.

The helper may use a grouped state structure if that makes the interface safer,
but it must not silently omit any mutable state. Avoid changing variable names,
comparison operators, candidate order, or helper-level evaluation logic during
the move.

After the extraction:

1. Compare the old and new block mechanically where practical.
2. Run `verify_bds_acceleration`.
3. Run the focused gradient-stop accounting check if bookkeeping was touched.
4. Inspect the diff for accidental comment-only or formatting changes outside
   the extracted block.

Acceptance gate: both strict equivalence targets pass, and the main iteration
still exposes the pre-poll phase boundary clearly.

## Stage 3: Extract the post-poll pattern/momentum phase

Move the entire post-poll acceleration protocol into one private helper. Keep
pattern and momentum together initially because momentum is conditional on the
pattern result and shares candidate state.

The helper must return all state that the subsequent termination and gradient
logic observes, including the updated base point, objective value, momentum,
productive-direction memory, histories, evaluation count, target/termination
flags, exitflag, and `post_poll_acceleration_succeeded`.

After the extraction, run:

1. `verify_bds_acceleration` for both strict targets;
2. `verify_gradient_stop_no_extra_evaluations`;
3. any focused acceleration tests already present in the repository;

Acceptance gate: no evaluation sequence, returned history, stopping decision,
or random behaviour changes.

## Stage 4: Simplify the main iteration orchestration

Once both helpers are independently verified, simplify the main iteration body
so that it visibly consists of:

1. iteration-state initialization;
2. pre-poll memory helper call;
3. ordinary BDS polling;
4. regular-poll result consolidation;
5. post-poll acceleration helper call;
6. common objective-window, gradient-stop, and termination checks.

Do not move common termination checks into acceleration helpers unless the
existing ordering is proven unchanged. The main solver should remain the owner
of cross-phase stopping priority and final output assembly.

Run both strict suites after each logical simplification, not only after the
whole stage.

## Stage 5: Review helper boundaries and comments

After the behaviour-preserving extraction is complete:

- decide whether the two helper names and interfaces are clear;
- remove local comments that merely restate moved code;
- move mechanism-specific explanations next to the corresponding helper;
- keep the main solver comments focused on phase ordering and shared state;
- defer another broad prose pass until the code structure is stable.

Run both strict suites one final time after comment and formatting changes as a
safeguard, even though comments should not affect execution.

## Stage 6: Final acceptance and handoff

Before declaring the refactor complete:

1. `verify_bds_acceleration` passes for acceleration on and off.
2. `verify_gradient_stop_no_extra_evaluations` passes.
3. No helper changes the public interface or introduces an unapproved option.
4. No function evaluation is added, removed, reordered, or hidden from the
   histories.
5. The diff contains only the planned helper extraction, associated private
   helper files, necessary call-site updates, and reviewed comments.
6. The final report identifies each helper, its state contract, and the
   verification commands and results.

The refactor is complete only when the main solver is structurally centered on
the ordinary BDS iteration/polling flow and both strict equivalence invariants
remain satisfied.
