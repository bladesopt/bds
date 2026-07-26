function analysis = analyze_gradient_no_stop_traces(run_root, profile_data_paths)
%ANALYZE_GRADIENT_NO_STOP_TRACES replays stopping rules without evaluations.

if nargin < 1 || isempty(run_root)
    error('analyze_gradient_no_stop_traces:MissingRunRoot', ...
        'Provide the completed gradient trace run root.');
end
if nargin < 2
    profile_data_paths = {};
end

grad_windows = [1, 2, 3, 5, 10];
consistency_tolerances = [0.003, 0.01, 0.03, 0.1, 0.3, 0.5];
reference_scale_factors = [0.001, 0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, ...
    100, 125, 150, 175, 200, 225, 250, 275, 300, 400, 500, 600, ...
    700, 800, 900, 1000, 2000, 3000, 5000, 10000, 10500, 11000, ...
    11500, 12000, 12500, 15000, ...
    17500, 20000, 22500, 25000, 27500, 30000, 100000];
grad_tol = 1e-6;
features = {'plain', 'linearly_transformed'};
tolerances = 10.^(-1:-1:-5);

parameters = all_parameters(grad_windows, consistency_tolerances, ...
    reference_scale_factors);
n_candidates = height(parameters);
feature_results = cell(numel(features), 1);

for i_feature = 1:numel(features)
    feature_name = features{i_feature};
    loaded = load(fullfile(run_root, [feature_name, '_traces.mat']), ...
        'runs', 'problem_names');
    n_problems = numel(loaded.runs);
    stop_counts = nan(n_problems, n_candidates);
    stop_merits = nan(n_problems, n_candidates);
    no_stop_counts = nan(n_problems, 1);
    no_stop_merits = nan(n_problems, 1);
    merit_inits = nan(n_problems, 1);
    merit_mins = nan(n_problems, 1);
    if ~isempty(profile_data_paths)
        [merit_inits, merit_mins] = load_profile_targets( ...
            profile_data_paths{i_feature}, loaded.problem_names);
    end

    for i_problem = 1:n_problems
        run = loaded.runs{i_problem};
        no_stop_counts(i_problem) = run.func_count;
        no_stop_merits(i_problem) = run.fopt;
        for i_candidate = 1:n_candidates
            [stop_counts(i_problem, i_candidate), ...
                stop_merits(i_problem, i_candidate)] = replay_candidate( ...
                    run, parameters(i_candidate, :), grad_tol);
        end
    end

    savings = no_stop_counts - stop_counts;
    activated = savings > 0;
    changed_merit = stop_merits ~= no_stop_merits;
    feature_result = struct();
    feature_result.feature_name = feature_name;
    feature_result.problem_names = loaded.problem_names;
    feature_result.no_stop_counts = no_stop_counts;
    feature_result.no_stop_merits = no_stop_merits;
    feature_result.stop_counts = stop_counts;
    feature_result.stop_merits = stop_merits;
    feature_result.activation_counts = sum(activated, 1)';
    feature_result.total_savings = sum(savings, 1)';
    feature_result.changed_merit_counts = sum(changed_merit, 1)';
    feature_result.safe_activation_counts = sum(activated & ~changed_merit, 1)';
    feature_result.output_solved_counts = output_solved_counts( ...
        merit_inits, merit_mins, stop_merits, tolerances);
    feature_results{i_feature} = feature_result;
end

activation_counts = zeros(n_candidates, 1);
total_savings = zeros(n_candidates, 1);
changed_merit_counts = zeros(n_candidates, 1);
safe_activation_counts = zeros(n_candidates, 1);
minimum_output_solved_count = inf(n_candidates, 1);
for i_feature = 1:numel(features)
    activation_counts = activation_counts + ...
        feature_results{i_feature}.activation_counts;
    total_savings = total_savings + feature_results{i_feature}.total_savings;
    changed_merit_counts = changed_merit_counts + ...
        feature_results{i_feature}.changed_merit_counts;
    safe_activation_counts = safe_activation_counts + ...
        feature_results{i_feature}.safe_activation_counts;
    minimum_output_solved_count = min(minimum_output_solved_count, ...
        min(feature_results{i_feature}.output_solved_counts, [], 2));
end

summary = parameters;
summary.activation_count = activation_counts;
summary.total_savings = total_savings;
summary.changed_merit_count = changed_merit_counts;
summary.safe_activation_count = safe_activation_counts;
summary.minimum_output_solved_count = minimum_output_solved_count;
summary = sortrows(summary, ...
    {'changed_merit_count', 'total_savings', 'activation_count'}, ...
    {'ascend', 'descend', 'descend'});

analysis = struct('status', 'COMPLETE', ...
    'created_at', char(datetime('now')), 'run_root', run_root, ...
    'grad_tol', grad_tol, 'tolerances', tolerances, 'parameters', parameters, ...
    'feature_results', {feature_results}, 'summary', summary, ...
    'uses_extra_function_evaluations', false);
save(fullfile(run_root, 'offline_parameter_analysis.mat'), ...
    'analysis', '-v7.3');
writetable(summary, fullfile(run_root, 'offline_parameter_summary.csv'));

disp(summary(1:min(30, height(summary)), :));
standard = summary(summary.reference_scale_factor == 1, :);
standard = sortrows(standard, ...
    {'changed_merit_count', 'total_savings', 'activation_count'}, ...
    {'ascend', 'descend', 'descend'});
fprintf('GRADIENT_OFFLINE_STANDARD_SCALE_TOP\n');
disp(standard(1:min(20, height(standard)), :));
fprintf('GRADIENT_OFFLINE_SAFE_ACTIVE=%d\n', ...
    nnz(summary.changed_merit_count == 0 & summary.activation_count > 0));
fprintf('GRADIENT_OFFLINE_ANALYSIS_OK\n');

end

function counts = output_solved_counts(merit_inits, merit_mins, ...
        stop_merits, tolerances)

n_candidates = size(stop_merits, 2);
if all(isnan(merit_inits))
    counts = nan(n_candidates, numel(tolerances));
    return
end
counts = zeros(n_candidates, numel(tolerances));
for i_tol = 1:numel(tolerances)
    threshold = tolerances(i_tol) * merit_inits + ...
        (1 - tolerances(i_tol)) * merit_mins;
    counts(:, i_tol) = sum(stop_merits <= threshold, 1)';
end

end

function [merit_inits, merit_mins] = load_profile_targets( ...
        profile_data_path, expected_problem_names)

loaded = load(profile_data_path, 'results_plibs');
assert(isscalar(loaded.results_plibs), 'Expected one problem library.');
results = loaded.results_plibs{1};
assert(isequal(results.problem_names(:), expected_problem_names(:)), ...
    'Trace and OptiProfiler problem ordering differ.');
merit_inits = results.merit_inits(:);
merit_mins = squeeze(min(min(results.merit_histories, [], 4, ...
    'omitnan'), [], 2, 'omitnan'));
merit_mins = min(merit_mins(:), merit_inits, 'omitnan');

end

function parameters = all_parameters(grad_windows, consistency_tolerances, ...
        reference_scale_factors)

[window_grid, consistency_grid, scale_grid] = ndgrid( ...
    grad_windows, consistency_tolerances, reference_scale_factors);
parameters = table(window_grid(:), consistency_grid(:), scale_grid(:), ...
    'VariableNames', {'grad_window_size', ...
        'consistency_tolerance', 'reference_scale_factor'});

end

function [stop_count, stop_merit] = replay_candidate(run, parameter, grad_tol)

stop_count = run.func_count;
stop_merit = run.fopt;
trace = run.trace;
window = nan(1, parameter.grad_window_size);
reference_is_set = false;
previous_gradient = [];
previous_x = [];

for i_trace = 1:numel(trace)
    item = trace(i_trace);
    gradient = item.estimated_gradient;
    upper_norm = item.estimated_gradient_norm + item.gradient_error_bound;
    same_point = ~isempty(previous_gradient) && isequal(item.xbase, previous_x);
    if same_point
        consistency_ratio = norm(gradient - previous_gradient) / ...
            max([1, norm(gradient), norm(previous_gradient)]);
    else
        consistency_ratio = inf;
    end

    if ~reference_is_set
        if consistency_ratio <= parameter.consistency_tolerance ...
                && item.gradient_error_bound ...
                    < max(1e-3, 1e-1 * item.estimated_gradient_norm)
            reference = upper_norm;
            reference_is_set = true;
        end
    else
        window = [window(2:end), upper_norm];
        relative_threshold = grad_tol * min(1, reference);
        reference_threshold = parameter.reference_scale_factor ...
            * grad_tol * max(1, reference);
        if all((window < relative_threshold) | ...
                (window < reference_threshold))
            stop_count = item.evaluation_count;
            stop_merit = item.fopt;
            return
        end
    end

    previous_gradient = gradient;
    previous_x = item.xbase;
end

end
