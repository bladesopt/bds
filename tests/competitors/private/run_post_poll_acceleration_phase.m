function [state, result] = run_post_poll_acceleration_phase(fun, state, config, iteration_step)
%RUN_POST_POLL_ACCELERATION_PHASE Pattern-step and momentum search after polling.
%
%   This helper owns the post-poll acceleration phase of
%   accelerated_bds_options. The caller enters this phase only after an
%   improving iteration whose net displacement exceeds max(alpha_tol).
%
%   The pattern direction is the normalized net displacement of the base
%   point during the current iteration, and the pattern step is the maximum
%   of the displacement norm and config.step_floor (= max(alpha_tol)). If
%   momentum extrapolation is enabled, the momentum vector is updated first
%   (regardless of whether the pattern search later succeeds) and normalized
%   into a momentum direction when its norm exceeds config.step_floor.
%
%   Pattern candidates with factors [1, 2, 4] are evaluated first, with
%   opportunistic stopping at the first non-improving candidate. Momentum
%   candidates are evaluated only when the pattern search produced no
%   improvement, the target has not been reached, and a momentum direction is
%   available; a momentum candidate identical to an already-evaluated failed
%   pattern point is not reevaluated. An accepted acceleration updates the
%   base point and may store its direction in the productive-direction
%   memory.
%
%   The interface has three layers. config is the read-only acceleration
%   configuration; this phase uses only use_iteration_pattern_step,
%   use_momentum_extrapolation, use_productive_direction_memory,
%   momentum_decay, productive_direction_memory_size, step_floor,
%   MaxFunctionEvaluations, ftarget, and output_xhist. state packs the
%   mutable solver/evaluation state the phase may update: xbase, fbase, nf,
%   fhist, xhist, invalid_points, productive_direction_memory, and momentum.
%   iteration_step is the net displacement of the current iteration; its norm
%   is computed internally. result is the phase result: succeeded records
%   whether an acceleration candidate was accepted, and target_reached
%   records whether the phase evaluated a point with f <= ftarget; the
%   caller owns the corresponding terminate/exitflag update.
%
%   The phase preserves target detection, evaluation accounting, and histories
%   of the original inline block. The caller applies the resulting
%   target_reached flag to update termination and exitflag.

result = struct('succeeded', false, 'target_reached', false);

iteration_step_norm = norm(iteration_step);
pattern_direction = iteration_step / iteration_step_norm;
pattern_step = max(iteration_step_norm, config.step_floor);

if config.use_momentum_extrapolation
    state.momentum = config.momentum_decay * state.momentum + ...
        (1.0 - config.momentum_decay) * pattern_direction;
    momentum_norm = norm(state.momentum);
    if momentum_norm > config.step_floor
        momentum_direction = state.momentum / momentum_norm;
    else
        momentum_direction = [];
    end
else
    momentum_direction = [];
end

factors = [1.0, 2.0, 4.0];
xbest = state.xbase;
fbest = state.fbase;
best_direction = [];
pattern_improved = false;
failed_pattern_point = [];

if config.use_iteration_pattern_step
    for i = 1:numel(factors)
        if state.nf >= config.MaxFunctionEvaluations
            break;
        end
        xnew = state.xbase + factors(i) * pattern_step * pattern_direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        state.nf = state.nf + 1;
        state.fhist(state.nf) = fnew_real;
        if config.output_xhist
            state.xhist(:, state.nf) = xnew;
            if ~is_valid
                state.invalid_points = [state.invalid_points, xnew];
            end
        end
        if fnew < fbest
            xbest = xnew;
            fbest = fnew;
            best_direction = pattern_direction;
            pattern_improved = true;
        else
            failed_pattern_point = xnew;
            break;
        end
        if fnew <= config.ftarget
            result.target_reached = true;
            break;
        end
    end
end

if ~result.target_reached && config.use_momentum_extrapolation && ...
        ~pattern_improved && ~isempty(momentum_direction) ...
        && state.nf < config.MaxFunctionEvaluations
    for i = 1:numel(factors)
        if state.nf >= config.MaxFunctionEvaluations
            break;
        end
        xnew = state.xbase + factors(i) * pattern_step * momentum_direction;
        if ~isempty(failed_pattern_point) && isequal(xnew, failed_pattern_point)
            break;
        end
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        state.nf = state.nf + 1;
        state.fhist(state.nf) = fnew_real;
        if config.output_xhist
            state.xhist(:, state.nf) = xnew;
            if ~is_valid
                state.invalid_points = [state.invalid_points, xnew];
            end
        end
        if fnew < fbest
            xbest = xnew;
            fbest = fnew;
            best_direction = momentum_direction;
        else
            break;
        end
        if fnew <= config.ftarget
            result.target_reached = true;
            break;
        end
    end
end

if fbest < state.fbase
    result.succeeded = true;
    state.xbase = xbest;
    state.fbase = fbest;
    if config.use_productive_direction_memory && ~isempty(best_direction)
        state.productive_direction_memory = remember_accelerated_bds_direction( ...
            state.productive_direction_memory, best_direction, pattern_step, ...
            config.productive_direction_memory_size);
    end
end

end
