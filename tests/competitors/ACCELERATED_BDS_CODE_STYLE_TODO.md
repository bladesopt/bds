# accelerated_bds_options code-style cleanup

This checklist records the cleanup needed for `accelerated_bds_options.m` to read like
`src/bds.m` was written by the same author. The solver behavior is frozen throughout.

## Non-negotiable behavior contract

- [x] With all acceleration switches disabled, `accelerated_bds_options.m` is equivalent to
  `src/bds.m` under the existing `verify_bds_acceleration` gate.
- [x] With all acceleration switches enabled, the default and `Algorithm='cbds'` paths are
  equivalent to `lean_evolved_bds.m` under the existing gate.
- [x] Gradient-stop diagnostics and the theta-aware reliability gate do not add function
  evaluations.
- [x] Public option names, defaults, exit flags, output fields, and evaluation order remain
  unchanged.

## Cleanup stages

- [x] Record the pre-cleanup verification baseline. MATLAB R2024b Update 2 is available and
  both formal gates pass on the pre-cleanup working tree.
- [x] Align the public header with `src/bds.m`: option order, section names, defaults, and
  reference-solver explanation.
- [x] Preserve the complete ordinary BDS polling loop and its original comments, ordering,
  history handling, and established names.
- [x] Rewrite the added acceleration blocks in the same narrative style as `bds.m`: explain
  intent immediately before a block and remove essay-like derivations from the main loop.
- [x] Replace abbreviated acceleration names (`prod_memory`, `dir_vec`, `x_cand`, `f_cand`,
  `iter_step`, `pattern_dir`, `alpha_pat`) by the descriptive naming pattern already used in
  `bds.m` (`productive_direction_memory`, `direction`, `xnew`, `fnew`,
  `iteration_step`, `pattern_direction`, `pattern_step`).
- [x] Keep the gradient-reference algorithm in the main loop but reduce its comments to the
  same density as the surrounding BDS code; use descriptive before/after state names for the
  optional diagnostic output.
- [x] Restore the author footer and the small formatting details shared with `bds.m`.
- [x] Align `set_accelerated_bds_options.m` with the explanatory style and option-ordering
  vocabulary of `set_options.m`, while retaining its stricter normalization helpers and the
  theta-aware central-difference explanation.
- [x] Run the relevant verification after each implementation stage.
- [x] Record the final verification results and review the complete diff.

## Verification record

The formal gates are:

```text
matlab -batch "addpath('tests'); verify_bds_acceleration"
matlab -batch "addpath('tests'); verify_gradient_stop_no_extra_evaluations"
```

The pre-cleanup baseline was recorded on the `rebuilt_code_style` branch:

```text
MATLAB: R2024b Update 2 (24.2.0.2773142)
verify_gradient_stop_no_extra_evaluations: GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
verify_bds_acceleration: passed (180 off cases + 630 default-on cases + 630 cbds-on cases)
```

The final post-cleanup verification after the structural naming and comment pass produced the
same results:

```text
verify_gradient_stop_no_extra_evaluations: GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
verify_bds_acceleration: VERIFY_BDS_ACCELERATION_OK
```

The first command is the hard equivalence gate for acceleration on/off behavior. The second
command is the hard no-extra-function-evaluation gate for the gradient stopping implementation.
