# Accelerated BDS Diagnostics Design Note

Status: design note only. No implementation change is required by this note.

## Purpose

`accelerated_bds_options.m` currently provides an optional
`output_gradient_stop_diagnostics` output. This note records the architectural
role of that output and possible future simplifications so that the design can
be revisited after the complete solver and its private helpers have been read.

This note is not a request to remove the diagnostics now. It is a reminder to
decide later whether the diagnostics should remain a public option, become an
internal development facility, or be incorporated into a broader solver-level
diagnostics interface.

## Current role

`gradient_stop_diagnostics` is not part of the BDS search state and does not
participate in any search, acceptance, acceleration, or termination decision.
It is an optional trace for analysing the estimated-gradient stopping
mechanism.

The trace is useful because the final solver output cannot reliably explain
several internal state transitions, including:

- the reference gradient norm before and after an update;
- whether two consecutive gradient estimates were computed at the same
  `xbase`;
- the consistency ratio between the current and previous gradient estimates;
- the gradient-window contents before and after the current estimate;
- the thresholds used by the stopping test;
- whether the stopping criterion was satisfied and whether it actually caused
  termination.

The trace also records selected iteration-level polling states, including
whether productive-direction memory, regular polling, or post-poll
acceleration produced an improvement. These fields explain the context in
which a gradient stopping check was reached; they do not make the acceleration
mechanisms dependent on the diagnostics output.

## Two-layer interpretation

The diagnostics have two distinct layers.

### Online instrumentation

While the solver is running, it captures transient values that may not be
recoverable after the solver finishes. Examples include the values before and
after updating `reference_grad_norm` and the gradient stopping window, the
current consistency comparison, and the polling outcomes of the current
iteration.

Online instrumentation is therefore necessary for any diagnostic field that
describes a state transition rather than only a final state.

### Postprocessed output

After the solver finishes, the collected records are returned as

```matlab
output.gradient_stop_diagnostics
```

The returned structure is postprocessed output: it is intended for tests,
experiments, and diagnosis, not for the solver's numerical decisions.

The current implementation combines these layers in the main solver. The
future design should keep the necessary online capture points while isolating
diagnostic record construction and output assembly from the core BDS logic.

## Architectural observations

The existence of a detailed gradient diagnostic trace does not imply that
every solver mechanism needs a separate diagnostics structure. A mechanism
should receive dedicated diagnostics only when its internal state is difficult
to reconstruct, its transitions require explanation, and the information is
needed for development, testing, or reproducible experiments.

The gradient stopping mechanism currently meets those conditions because its
reference-scale initialization, consistency test, error bound, and window
criterion interact in ways that are not visible from `grad_hist`, `fhist`, or
the final `exitflag` alone. Productive-direction memory, iteration-pattern
steps, and momentum extrapolation should not automatically acquire parallel
diagnostics interfaces merely for symmetry.

## Possible future directions

After the complete solver has been reviewed, consider the following options in
order of increasing architectural scope:

1. Keep the public option, but initialize and append the diagnostics only when
   `output_gradient_stop_diagnostics` is true.
2. Keep the diagnostic capability but move the schema and record-construction
   code into private helper functions, leaving only small capture points in the
   main solver.
3. Replace mechanism-specific public traces with one optional solver-level
   diagnostics or event interface. Estimated-gradient stopping and acceleration
   phases could then contribute different record types to a common trace.
4. Make the diagnostics an internal testing/development facility rather than a
   permanent public option, after all in-repository callers have been migrated
   and the required regression coverage is established.

These possibilities are alternatives for later evaluation, not a decision to
apply them immediately. In particular, a unified interface should not be
introduced merely by moving a large list of fields into another large helper.

## Non-goals for the current cleanup

This design note does not authorize any of the following changes:

- deleting `gradient_stop_diagnostics`;
- adding diagnostics options for every acceleration mechanism;
- changing the gradient stopping criterion or any acceleration calculation;
- adding function evaluations, changing evaluation order, or changing random
  behaviour;
- weakening either strict equivalence invariant.

## Re-evaluation point

Revisit this note after the complete `accelerated_bds_options.m` and all
relevant private helpers have been read and the current code simplification
pass is complete. At that point, decide explicitly whether to retain,
internalize, or generalize the diagnostics design. Record the decision and
run the strict behavioural checks before accepting any implementation change.

## Non-negotiable invariants

Any future diagnostics refactor must preserve both strict invariants:

1. With all acceleration switches disabled,
   `accelerated_bds_options.m` must remain exactly equivalent to `bds.m` for
   the same explicit solver options, including function evaluation sequence and
   count, outputs, histories, stopping behaviour, exit flag, diagnostics, and
   random behaviour.
2. With all acceleration switches enabled,
   `accelerated_bds_options.m` must remain exactly equivalent to
   `lean_evolved_bds.m` for the default algorithm and explicit
   `Algorithm = "cbds"`, with the same scope of equivalence.

The mandatory checker is:

```matlab
addpath(genpath(pwd));
verify_bds_acceleration
```

Diagnostics changes must be accepted only after this checker and any focused
diagnostic regression tests pass.
