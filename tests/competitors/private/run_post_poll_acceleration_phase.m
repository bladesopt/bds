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
%RUN_POST_POLL_ACCELERATION_PHASE Pattern-step and momentum search after polling.
%
%   This helper owns the post-poll acceleration phase of
%   accelerated_bds_options. The caller enters this phase only after an
%   improving iteration whose net displacement exceeds max(alpha_tol).
%
%   The pattern direction is the normalized net displacement of the base
%   point during the current iteration, and the pattern step is
%   max(iteration_step_norm, max(alpha_tol)). If momentum extrapolation is
%   enabled, the momentum vector is updated first (regardless of whether the
%   pattern search later succeeds) and normalized into a momentum direction
%   when its norm exceeds max(alpha_tol).
%
%   Pattern candidates with factors [1, 2, 4] are evaluated first, with
%   opportunistic stopping at the first non-improving candidate. Momentum
%   candidates are evaluated only when the pattern search produced no
%   improvement, the target has not been reached, and a momentum direction is
%   available; a momentum candidate identical to an already-evaluated failed
%   pattern point is not reevaluated. An accepted acceleration updates the
%   base point and may store its direction in the productive-direction
%   memory. The phase preserves the target checks, evaluation accounting,
%   histories, and termination/exitflag handling of the original inline
%   block.

post_poll_acceleration_succeeded = false;

pattern_direction = iteration_step / iteration_step_norm;
pattern_step = max(iteration_step_norm, max(alpha_tol));

if use_momentum_extrapolation
    momentum = momentum_decay * momentum + ...
        (1.0 - momentum_decay) * pattern_direction;
    momentum_norm = norm(momentum);
    if momentum_norm > max(alpha_tol)
        momentum_direction = momentum / momentum_norm;
    else
        momentum_direction = [];
    end
else
    momentum_direction = [];
end

factors = [1.0, 2.0, 4.0];
xbest = xbase;
fbest = fbase;
best_direction = [];
pattern_improved = false;
failed_pattern_point = [];

if use_iteration_pattern_step
    for i = 1:numel(factors)
        if nf >= MaxFunctionEvaluations
            break;
        end
        xnew = xbase + factors(i) * pattern_step * pattern_direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        nf = nf + 1;
        fhist(nf) = fnew_real;
        if output_xhist
            xhist(:, nf) = xnew;
            if ~is_valid
                invalid_points = [invalid_points, xnew];
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
        if fnew <= ftarget
            target_reached = true;
            break;
        end
    end
end

if ~target_reached && use_momentum_extrapolation && ...
        ~pattern_improved && ~isempty(momentum_direction) ...
        && nf < MaxFunctionEvaluations
    for i = 1:numel(factors)
        if nf >= MaxFunctionEvaluations
            break;
        end
        xnew = xbase + factors(i) * pattern_step * momentum_direction;
        if ~isempty(failed_pattern_point) && isequal(xnew, failed_pattern_point)
            break;
        end
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        nf = nf + 1;
        fhist(nf) = fnew_real;
        if output_xhist
            xhist(:, nf) = xnew;
            if ~is_valid
                invalid_points = [invalid_points, xnew];
            end
        end
        if fnew < fbest
            xbest = xnew;
            fbest = fnew;
            best_direction = momentum_direction;
        else
            break;
        end
        if fnew <= ftarget
            target_reached = true;
            break;
        end
    end
end

if fbest < fbase
    post_poll_acceleration_succeeded = true;
    xbase = xbest;
    fbase = fbest;
    if use_productive_direction_memory && ~isempty(best_direction)
        productive_direction_memory = remember_accelerated_bds_direction( ...
            productive_direction_memory, best_direction, pattern_step, ...
            productive_direction_memory_size);
    end
end
if target_reached
    terminate = true;
    exitflag = get_exitflag("FTARGET_REACHED");
end

end
