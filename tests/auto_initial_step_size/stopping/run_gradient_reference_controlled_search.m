function result = run_gradient_reference_controlled_search(reference_scale_factor)
%RUN_GRADIENT_REFERENCE_CONTROLLED_SEARCH checks no-extra-evaluation gates.

if nargin < 1 || isempty(reference_scale_factor)
    reference_scale_factor = 1e-3;
end
validateattributes(reference_scale_factor, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});

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
consistency_tolerances = [0.01, 0.03, 0.1, 0.3];
real_seed = 211;
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_root = fullfile(tests_dir, 'testdata', ...
    ['gradient_reference_controlled_search_', timestamp]);
mkdir(run_root);

runs = cell(numel(problem_names), numel(feature_names), ...
    numel(consistency_tolerances));
for i_problem = 1:numel(problem_names)
    problem = s2mpj_load(problem_names{i_problem});
    for i_feature = 1:numel(feature_names)
        feature = Feature(feature_names{i_feature});
        [A, b] = feature.modifier_affine(real_seed, problem);
        for i_tol = 1:numel(consistency_tolerances)
            featured_problem = FeaturedProblem( ...
                problem, feature, 500 * problem.n, real_seed);
            options = solver_options(featured_problem.x0, ...
                consistency_tolerances(i_tol), reference_scale_factor);
            [xopt, fopt, exitflag, output] = accelerated_bds_options( ...
                @(x) featured_problem.fun(x), featured_problem.x0, options);
            trace = add_true_gradient_diagnostics( ...
                output.gradient_stop_diagnostics, problem, A, b);
            run = struct('problem_name', problem_names{i_problem}, ...
                'feature_name', feature_names{i_feature}, ...
                'consistency_tolerance', consistency_tolerances(i_tol), ...
                'x0', featured_problem.x0, 'xopt', xopt, 'fopt', fopt, ...
                'exitflag', exitflag, 'output', output, 'trace', trace, ...
                'true_gradient_at_output', A' * problem.grad(A * xopt + b));
            runs{i_problem, i_feature, i_tol} = run;
            initialized = find([trace.reference_initialized], 1, 'first');
            stopped = find([trace.stop_decision], 1, 'first');
            if isempty(initialized); initialized = 0; end
            if isempty(stopped); stopped = 0; end
            fprintf(['GRAD_REF_CONTROLLED=PROBLEM:%s,FEATURE:%s,TOL:%.3g,', ...
                'NF:%d,FOPT:%.17g,EXIT:%d,INIT:%d,STOP:%d,TRUE_G:%.17g\n'], ...
                problem_names{i_problem}, feature_names{i_feature}, ...
                consistency_tolerances(i_tol), output.funcCount, fopt, ...
                exitflag, initialized, stopped, norm(run.true_gradient_at_output));
        end
    end
end

result = struct('status', 'COMPLETE', 'created_at', char(datetime('now')), ...
    'run_root', run_root, 'problem_names', {problem_names}, ...
    'feature_names', {feature_names}, ...
    'consistency_tolerances', consistency_tolerances, ...
    'reference_scale_factor', reference_scale_factor, ...
    'real_seed', real_seed, 'runs', {runs});
save(fullfile(run_root, 'controlled_search.mat'), 'result', '-v7.3');
fprintf('GRADIENT_REFERENCE_CONTROLLED_SEARCH_RUN_ROOT=%s\n', run_root);
fprintf('GRADIENT_REFERENCE_CONTROLLED_SEARCH_OK\n');

end

function options = solver_options(x0, consistency_tolerance, reference_scale_factor)

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
options.use_estimated_gradient_stop = true;
options.grad_window_size = 1;
options.grad_tol = 1e-6;
options.lipschitz_constant = 1e3;
options.use_gradient_reference_consistency = true;
options.grad_reference_finite_difference_error_tol = ...
    consistency_tolerance * (0.5^2) / (1 - 0.5^2);
options.grad_reference_relative_tol = reference_scale_factor * options.grad_tol;
options.output_gradient_stop_diagnostics = true;

end

function trace = add_true_gradient_diagnostics(trace, problem, A, b)

for i = 1:numel(trace)
    true_gradient = A' * problem.grad(A * trace(i).xbase + b);
    trace(i).true_gradient = true_gradient;
    trace(i).true_gradient_norm = norm(true_gradient);
    trace(i).actual_gradient_error = ...
        norm(trace(i).estimated_gradient - true_gradient);
end

end
