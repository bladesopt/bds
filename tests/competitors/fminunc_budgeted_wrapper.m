function x = fminunc_budgeted_wrapper(fun, x0, options)
%FMINUNC_BUDGETED_WRAPPER Run finite-difference BFGS under an objective budget.

if nargin < 3
    options = struct();
end

n = numel(x0);
max_objective_evaluations = options.MaxObjectiveEvaluations;
with_gradient = isfield(options, 'with_gradient') && options.with_gradient;

if isfield(options, 'StepTolerance')
    step_tolerance = options.StepTolerance;
else
    step_tolerance = 1e-6;
end
if isfield(options, 'ftarget')
    ftarget = options.ftarget;
else
    ftarget = -Inf;
end
if isfield(options, 'noise_level')
    noise_level = options.noise_level;
else
    noise_level = 1e-3;
end

if with_gradient
    evaluations_per_callback = n + 1;
else
    evaluations_per_callback = 1;
end
max_callbacks = floor(max_objective_evaluations/evaluations_per_callback);
if max_callbacks < 1
    error('fminunc_budgeted_wrapper:InsufficientBudget', ...
        'The objective budget is insufficient for one complete callback.');
end

optim_options = optimoptions('fminunc', ...
    'Algorithm', 'quasi-newton', ...
    'HessUpdate', 'bfgs', ...
    'MaxFunctionEvaluations', max_callbacks, ...
    'MaxIterations', 1e20, ...
    'ObjectiveLimit', ftarget, ...
    'StepTolerance', step_tolerance, ...
    'OptimalityTolerance', eps, ...
    'SpecifyObjectiveGradient', with_gradient);

if with_gradient
    objective = @(x) objective_with_forward_difference( ...
        fun, x, noise_level);
else
    objective = fun;
end
x = fminunc(objective, x0, optim_options);

end

function [f, g] = objective_with_forward_difference(fun, x, noise_level)

f = fun(x);
h = sqrt(max(abs(f), 1)*noise_level);
n = numel(x);
g = NaN(n, 1);
for i = 1:n
    x_fd = x;
    x_fd(i) = x_fd(i) + h;
    g(i) = (fun(x_fd) - f)/h;
end

g(isnan(g)) = 0;
grad_max = 1e10;
g = min(grad_max, max(-grad_max, g));

end
