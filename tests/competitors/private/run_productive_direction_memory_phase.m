function [xbase, fbase, nf, fhist, xhist, invalid_points, ...
    target_reached, terminate, exitflag, ...
    iteration_improved, pre_poll_memory_succeeded, ...
    productive_direction_memory] = run_productive_direction_memory_phase( ...
    fun, xbase, fbase, alpha_all, productive_direction_memory, ...
    use_productive_direction_memory, nf, MaxFunctionEvaluations, ftarget, ...
    fhist, xhist, invalid_points, output_xhist, ...
    target_reached, terminate, exitflag, iteration_improved)
%RUN_PRODUCTIVE_DIRECTION_MEMORY_PHASE Pre-poll search over retained productive directions.
%
%   This helper owns the pre-poll productive-direction memory phase of
%   accelerated_bds_options. Before the regular block-polling phase of an
%   iteration, the retained productive directions are considered in list
%   order. For each direction, a candidate is evaluated at the trial step
%   max(mean(alpha_all), stored_step). An accepted candidate (one that
%   improves fbase) is followed by at most two extrapolation evaluations at
%   successively doubled step lengths, the direction is moved to the front of
%   the memory, and the phase stops. The phase also stops when the target is
%   reached or the function-evaluation budget is exhausted.
%
%   The phase preserves the memory list order, candidate acceptance and
%   target checks, history and invalid-point recording, evaluation budget
%   handling, and termination/exitflag precedence of the original inline
%   block.

pre_poll_memory_succeeded = false;

% Try the productive directions recorded from successful polling steps.
if use_productive_direction_memory && ...
        ~isempty(productive_direction_memory) && nf < MaxFunctionEvaluations
    alpha_average = mean(alpha_all);
    for i = 1:numel(productive_direction_memory)
        if nf >= MaxFunctionEvaluations
            break;
        end
        direction = productive_direction_memory(i).direction;
        step = max(alpha_average, productive_direction_memory(i).step);
        xnew = xbase + step * direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        nf = nf + 1;
        fhist(nf) = fnew_real;
        if output_xhist
            xhist(:, nf) = xnew;
            if ~is_valid
                invalid_points = [invalid_points, xnew];
            end
        end
        if fnew <= ftarget
            target_reached = true;
            terminate = true;
            exitflag = get_exitflag("FTARGET_REACHED");
        end
        if fnew < fbase
            xbase = xnew;
            fbase = fnew;
            iteration_improved = true;
            pre_poll_memory_succeeded = true;
            if target_reached
                break;
            end
            [xbase, fbase, nf, fhist, xhist, invalid_points] = try_accelerated_bds_extrapolation( ...
                fun, xbase, fbase, direction, step * 2.0, nf, ...
                MaxFunctionEvaluations, ftarget, fhist, xhist, ...
                invalid_points, output_xhist);
            productive_direction_memory(i) = [];
            productive_direction_memory = insert_accelerated_bds_memory_front( ...
                productive_direction_memory, direction, step);
            if fbase <= ftarget
                target_reached = true;
                terminate = true;
                exitflag = get_exitflag("FTARGET_REACHED");
            end
            break;
        end
        if target_reached
            break;
        end
    end
end

end
