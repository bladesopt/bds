# Acceleration Phase Helper Contracts

Implementation note accompanying
`ACCELERATED_BDS_ACCELERATION_REFACTOR_PLAN.md` (Stage 1). These contracts are
written before any code movement and must not change solver behaviour.

## State inventory of the acceleration phases

### Pre-poll productive-direction memory phase

Current location: `accelerated_bds_options.m`, the block starting at
`% Try the productive directions recorded from successful polling steps.`

- Reads: `options.use_productive_direction_memory`,
  `productive_direction_memory`, `nf`, `MaxFunctionEvaluations`, `alpha_all`
  (only `mean(alpha_all)`), `xbase`, `fbase`, `ftarget`, `fun`, `output_xhist`.
- Writes: `xbase`, `fbase`, `nf`, `fhist`, `xhist`, `invalid_points`,
  `target_reached`, `terminate`, `exitflag`, `iteration_improved`,
  `pre_poll_memory_succeeded`, `productive_direction_memory`.
- Calls: `eval_fun`, `try_accelerated_bds_extrapolation`,
  `insert_accelerated_bds_memory_front`, `get_exitflag`.

### Post-poll acceleration phase (pattern step + momentum extrapolation)

Current location: `accelerated_bds_options.m`, the block starting at
`% Try a pattern direction followed, if necessary, by the momentum direction.`

- Entry guard reads: `terminate`, `iteration_improved`,
  `iteration_step_norm`, `alpha_tol`, `nf`, `MaxFunctionEvaluations`,
  `options.use_iteration_pattern_step`, `options.use_momentum_extrapolation`.
- Body reads: `iteration_step`, `iteration_step_norm`, `momentum`,
  `momentum_decay`, `alpha_tol`, `xbase`, `fbase`, `ftarget`, `fun`,
  `output_xhist`, `options.use_iteration_pattern_step`,
  `options.use_momentum_extrapolation`,
  `options.use_productive_direction_memory`, `productive_direction_memory`,
  `productive_direction_memory_size`, `nf`, `MaxFunctionEvaluations`.
- Writes: `momentum` (updated whenever `use_momentum_extrapolation` is on and
  the phase is entered, even if the pattern search later succeeds), `xbase`,
  `fbase`, `nf`, `fhist`, `xhist`, `invalid_points`, `target_reached`,
  `terminate`, `exitflag`, `post_poll_acceleration_succeeded`,
  `productive_direction_memory`.
- Phase-local temporaries: `pattern_direction`, `pattern_step`,
  `momentum_norm`, `momentum_direction`, `factors`, `xbest`, `fbest`,
  `best_direction`, `pattern_improved`, `failed_pattern_point`, and the
  per-candidate `xnew`/`fnew`/`fnew_real`/`is_valid`.
- Calls: `eval_fun`, `remember_accelerated_bds_direction`, `get_exitflag`.

## Helper contracts

### `run_productive_direction_memory_phase`

```matlab
function [xbase, fbase, nf, fhist, xhist, invalid_points, ...
    target_reached, terminate, exitflag, ...
    iteration_improved, pre_poll_memory_succeeded, ...
    productive_direction_memory] = run_productive_direction_memory_phase( ...
    fun, xbase, fbase, alpha_all, productive_direction_memory, ...
    use_productive_direction_memory, nf, MaxFunctionEvaluations, ftarget, ...
    fhist, xhist, invalid_points, output_xhist, ...
    target_reached, terminate, exitflag, iteration_improved)
```

Owns the full pre-poll block including its entry condition
(`use_productive_direction_memory && ~isempty(productive_direction_memory)
&& nf < MaxFunctionEvaluations`). Initializes
`pre_poll_memory_succeeded` to false and sets it true only when a retained
direction is accepted. All other in/out arguments are threaded through
unchanged in meaning. Preserves list order, duplicate handling (unchanged,
still owned by `remember_accelerated_bds_direction`), the trial step
`max(mean(alpha_all), stored_step)`, candidate acceptance, target checks, the
at-most-two extrapolation evaluations after an accepted direction, history and
invalid-point recording, evaluation budget, termination and exitflag
precedence.

### `run_post_poll_acceleration_phase`

```matlab
function [xbase, fbase, nf, fhist, xhist, invalid_points, ...
    target_reached, terminate, exitflag, momentum, ...
    productive_direction_memory, post_poll_acceleration_succeeded] = ...
    run_post_poll_acceleration_phase( ...
    fun, xbase, fbase, iteration_step, iteration_step_norm, ...
    momentum, momentum_decay, productive_direction_memory, ...
    productive_direction_memory_size, alpha_tol, ...
    use_iteration_pattern_step, use_momentum_extrapolation, ...
    use_productive_direction_memory, ...
    nf, MaxFunctionEvaluations, ftarget, fhist, xhist, invalid_points, ...
    output_xhist, target_reached, terminate, exitflag)
```

The entry condition (`~terminate && iteration_improved &&
iteration_step_norm > max(alpha_tol) && nf < MaxFunctionEvaluations &&
(use_iteration_pattern_step || use_momentum_extrapolation)`) stays at the call
site in the main solver, so the main loop keeps the phase ordering visible.
`post_poll_acceleration_succeeded` is initialized to false inside the helper
and set true only when an accepted candidate improves `fbase`. The helper owns
pattern-direction/step construction, the momentum update and normalization
(performed before any candidate search), the pattern candidates with factors
`[1, 2, 4]`, the momentum candidates attempted only when the pattern search
did not improve, the suppression of reevaluating an identical failed pattern
point, the accepted-acceleration memory insertion, and all target, budget,
history, termination and exitflag updates of the moved block.

## Shared state that stays in the main solver

`iteration_step`, `iteration_step_norm`, and `iteration_improved` are computed
in the main iteration body (they consolidate the polling result and feed the
gradient estimation and stopping logic). `xbase_iteration_start`, `fbase_iteration_start`,
`regular_poll_succeeded`, all ordinary BDS polling state, `fopt`/`xopt`,
`fopt_window`, the objective-change stop, and the gradient estimation/stop
logic remain in the main solver.
