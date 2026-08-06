function result = run_gradient_stop_concrete_diagnostics()
%RUN_GRADIENT_STOP_CONCRETE_DIAGNOSTICS traces known gradient-stop cases.

repo_dir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
tests_dir = fullfile(repo_dir, 'tests');
cd(repo_dir);
setup;
addpath(tests_dir);
addpath(fullfile(tests_dir, 'competitors'));
optiprofiler_root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
addpath(fullfile(optiprofiler_root, 'src'));
addpath(fullfile(optiprofiler_root, 'problem_libs'));
addpath(fullfile(optiprofiler_root, 'problem_libs', 's2mpj'));

problem_names = {'SBRYBND', 'SCURLY20', 'POWERSUM'};
feature_names = {'plain', 'linearly_transformed'};
solver_kinds = {'no_stop', 'gradient_stop'};
real_seed = 211;
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_root = fullfile(tests_dir, 'testdata', ...
    ['gradient_stop_concrete_diagnostics_', timestamp]);
mkdir(run_root);

runs = cell(numel(problem_names), numel(feature_names), numel(solver_kinds));
for i_problem = 1:numel(problem_names)
    problem = s2mpj_load(problem_names{i_problem});
    for i_feature = 1:numel(feature_names)
        feature = Feature(feature_names{i_feature});
        [A, b] = feature.modifier_affine(real_seed, problem);
        for i_solver = 1:numel(solver_kinds)
            featured_problem = FeaturedProblem( ...
                problem, feature, 500 * problem.n, real_seed);
            options = solver_options(featured_problem.x0, ...
                strcmp(solver_kinds{i_solver}, 'gradient_stop'));
            [xopt, fopt, exitflag, output] = accelerated_bds_options( ...
                @(x) featured_problem.fun(x), featured_problem.x0, options);
            trace = add_true_gradient_diagnostics( ...
                output.gradient_stop_diagnostics, problem, A, b);

            run = struct();
            run.problem_name = problem_names{i_problem};
            run.loaded_problem_name = problem.name;
            run.dimension = problem.n;
            run.feature_name = feature_names{i_feature};
            run.real_seed = real_seed;
            run.transformation_A = A;
            run.transformation_b = b;
            run.solver_kind = solver_kinds{i_solver};
            run.options = options;
            run.x0 = featured_problem.x0;
            run.xopt = xopt;
            run.fopt = fopt;
            run.exitflag = exitflag;
            run.output = output;
            run.output.gradient_stop_diagnostics = trace;
            run.true_gradient_at_output = A' * problem.grad(A * xopt + b);
            run.true_gradient_norm_at_output = norm(run.true_gradient_at_output);
            runs{i_problem, i_feature, i_solver} = run;

            stopped = find([trace.stop_decision], 1, 'first');
            if isempty(stopped)
                stopped = 0;
            end
            fprintf(['GRADIENT_DIAG_PROBLEM=%s,FEATURE=%s,SOLVER=%s,', ...
                'N=%d,NF=%d,FOPT=%.17g,EXITFLAG=%d,TRACE=%d,STOP_TRACE=%d,', ...
                'TRUE_GRAD_OUT=%.17g\n'], problem_names{i_problem}, ...
                feature_names{i_feature}, solver_kinds{i_solver}, problem.n, ...
                output.funcCount, fopt, exitflag, numel(trace), stopped, ...
                run.true_gradient_norm_at_output);
            if stopped > 0
                item = trace(stopped);
                fprintf(['GRADIENT_DIAG_STOP_DETAIL=EST=%.17g,TRUE=%.17g,', ...
                    'ACTUAL_ERROR=%.17g,BOUND=%.17g,RELTHRESH=%.17g,', ...
                    'ABSTHRESH=%.17g,PREMEM=%d,POLL=%d,POSTACCEL=%d\n'], ...
                    item.estimated_gradient_norm, item.true_gradient_norm, ...
                    item.actual_gradient_error, item.gradient_error_bound, ...
                    item.threshold_relative, item.threshold_absolute_fallback, ...
                    item.pre_poll_memory_succeeded, item.regular_poll_succeeded, ...
                    item.post_poll_acceleration_succeeded);
            end
        end
    end
end

result = struct();
result.status = 'COMPLETE';
result.created_at = char(datetime('now'));
result.run_root = run_root;
result.problem_names = problem_names;
result.feature_names = feature_names;
result.solver_kinds = solver_kinds;
result.real_seed = real_seed;
result.runs = runs;
save(fullfile(run_root, 'concrete_diagnostics.mat'), 'result', '-v7.3');
fprintf('GRADIENT_STOP_CONCRETE_DIAGNOSTICS_RUN_ROOT=%s\n', run_root);
fprintf('GRADIENT_STOP_CONCRETE_DIAGNOSTICS_OK\n');

end

function options = solver_options(x0, use_gradient_stop)

options = struct();
options.Algorithm = 'cbds';
options.MaxFunctionEvaluations = 500 * numel(x0);
options.StepTolerance = 1e-6;
options.ftarget = -Inf;
options.expand = 1.8;
options.shrink = 0.5;
options.is_noisy = false;
options.forcing_function = @(alpha) alpha^2;
options.reduction_factor = [0, eps, eps];
options.polling_inner = 'opportunistic';
options.cycling_inner = 1;
options.seed = 0;
options.use_productive_direction_memory = true;
options.use_iteration_pattern_step = true;
options.use_momentum_extrapolation = true;
options.alpha_init = max(abs(x0(:)), options.StepTolerance);
options.alpha_init(x0(:) == 0) = 1;
options.use_function_value_stop = false;
options.use_estimated_gradient_stop = use_gradient_stop;
options.grad_window_size = 1;
options.grad_tol = 1e-6;
options.lipschitz_constant = 1e3;
options.output_xhist = true;
options.output_alpha_hist = true;
options.output_grad_hist = true;
options.output_gradient_stop_diagnostics = true;

end

function trace = add_true_gradient_diagnostics(trace, problem, A, b)

for i = 1:numel(trace)
    true_gradient = A' * problem.grad(A * trace(i).xbase + b);
    actual_error = norm(trace(i).estimated_gradient - true_gradient);
    trace(i).true_gradient = true_gradient;
    trace(i).true_gradient_norm = norm(true_gradient);
    trace(i).actual_gradient_error = actual_error;
    trace(i).error_bound_ratio = actual_error / trace(i).gradient_error_bound;
    trace(i).relative_estimation_error = actual_error / max(norm(true_gradient), realmin);
    trace(i).gradient_alignment = ...
        dot(trace(i).estimated_gradient, true_gradient) / ...
        max(norm(trace(i).estimated_gradient) * norm(true_gradient), realmin);
end

end
