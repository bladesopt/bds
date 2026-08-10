function [state, result] = run_productive_direction_memory_phase(fun, state, config, alpha_average)
%RUN_PRODUCTIVE_DIRECTION_MEMORY_PHASE Pre-poll search over retained productive directions.
%
%   This helper owns the pre-poll productive-direction memory phase of
%   accelerated_bds_options. Before the regular block-polling phase of an
%   iteration, the retained productive directions are considered in list
%   order. For each direction, a candidate is evaluated at the trial step
%   max(alpha_average, stored_step). An accepted candidate (one that
%   improves fbase) is followed by at most two extrapolation evaluations at
%   successively doubled step lengths, the direction is moved to the front of
%   the memory, and the phase stops. The phase also stops when the target is
%   reached or the function-evaluation budget is exhausted.
%
%   The interface has three layers. config is the read-only acceleration
%   configuration; this phase uses only use_productive_direction_memory,
%   MaxFunctionEvaluations, ftarget, and output_xhist. state packs the mutable
%   solver/evaluation state the phase may update: xbase, fbase, nf, fhist,
%   xhist, invalid_points, and productive_direction_memory. alpha_average is
%   the mean of the current per-block step sizes, precomputed by the caller.
%   result is the phase result: succeeded records whether a retained
%   direction was accepted, and target_reached records whether the phase
%   evaluated a point with f <= ftarget; the caller owns the corresponding
%   terminate/exitflag update.
%
%   The phase preserves the memory list order, candidate acceptance and
%   target checks, history and invalid-point recording, evaluation budget
%   handling, and termination/exitflag precedence of the original inline
%   block.

result = struct('succeeded', false, 'target_reached', false);

% Try the productive directions recorded from successful polling steps.
if config.use_productive_direction_memory && ...
        ~isempty(state.productive_direction_memory) && state.nf < config.MaxFunctionEvaluations
    for i = 1:numel(state.productive_direction_memory)
        if state.nf >= config.MaxFunctionEvaluations
            break;
        end
        direction = state.productive_direction_memory(i).direction;
        step = max(alpha_average, state.productive_direction_memory(i).step);
        xnew = state.xbase + step * direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        state.nf = state.nf + 1;
        state.fhist(state.nf) = fnew_real;
        if config.output_xhist
            state.xhist(:, state.nf) = xnew;
            if ~is_valid
                state.invalid_points = [state.invalid_points, xnew];
            end
        end
        if fnew <= config.ftarget
            result.target_reached = true;
        end
        if fnew < state.fbase
            state.xbase = xnew;
            state.fbase = fnew;
            result.succeeded = true;
            if result.target_reached
                break;
            end
            [state.xbase, state.fbase, state.nf, state.fhist, state.xhist, ...
                state.invalid_points] = try_accelerated_bds_extrapolation( ...
                fun, state.xbase, state.fbase, direction, step * 2.0, state.nf, ...
                config.MaxFunctionEvaluations, config.ftarget, state.fhist, state.xhist, ...
                state.invalid_points, config.output_xhist);
            state.productive_direction_memory(i) = [];
            state.productive_direction_memory = insert_accelerated_bds_memory_front( ...
                state.productive_direction_memory, direction, step);
            if state.fbase <= config.ftarget
                result.target_reached = true;
            end
            break;
        end
        if result.target_reached
            break;
        end
    end
end

end
