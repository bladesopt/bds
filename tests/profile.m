function [output] = profile(parameters)
% Draw performance profiles.

% Record the current path.
oldpath = path(); 
% Restore the "right out of the box" path of MATLAB. 
restoredefaultpath;  
% Record the current directory.
old_dir = pwd();

% Add the paths that we need to use in the performance profile into the MATLAB
% search path.
current_path = mfilename("fullpath");
path_tests = fileparts(current_path);
path_root = fileparts(path_tests);
path_src = fullfile(path_root, "src");
path_competitors = fullfile(path_tests, "competitors");
addpath(path_root);
addpath(path_tests);
addpath(path_src);
addpath(path_competitors);

% If the folder of testdata does not exist, make a new one.
path_testdata = fullfile(path_tests, "testdata");
if ~exist(path_testdata, "dir")
    mkdir(path_testdata);
end

% In case no solvers are input, then throw an error.
if ~isfield(parameters, "solvers_options") || length(parameters.solvers_options) < 2
    error("There should be at least two solvers.")
end

% Get the parameters that the test needs.
parameters = set_profile_options(parameters);

% Tell MATLAB where to find MatCUTEst.
locate_matcutest();
% Tell MATLAB where to find prima.
locate_prima();

% Get list of problems
s.type = parameters.problems_type; % Unconstrained: 'u'
s.mindim = parameters.problems_mindim; % Minimum of dimension
s.maxdim = parameters.problems_maxdim; % Maximum of dimension
s.blacklist = [];
% TODO: Not problems, which solvers will crash?
s.blacklist = [s.blacklist, {}];
% Problems that takes too long to solve.
% {'FBRAIN3LS'} and {'STRATEC'} take too long for fminunc(not for ds and bds).
% {'LRCOVTYPE'} and {'LRIJCNN1'} take long for ds and bds(not for fminunc).
% TODO: check why {'LRIJCNN1'} takes so long to run?
% TODO: check why {'PARKCH'} takes so long to run?
% TODO: check why {'STRATEC'} takes so long to run?
s.blacklist = [{'LRCOVTYPE'},{'LRIJCNN1'},{'PARKCH'},{'STRATEC'}];

problem_names = secup(s);

fprintf("We will load %d problems\n\n", length(problem_names))

% Some fixed (relatively) options
% TODO: Read two papers: What Every Computer Scientist Should Know About
% Floating-Point Arithmetic; stability and accuracy numerical(written by Higham).

% Set maxfun for frec.
if isfield(parameters, "maxfun_factor") && isfield(parameters, "maxfun")
    maxfun_frec = max(parameters.maxfun_factor*parameters.problems_maxdim, parameters.maxfun);
elseif isfield(parameters, "maxfun_factor")
    maxfun_frec = parameters.maxfun_factor*parameters.problems_maxdim;
elseif isfield(parameters, "maxfun")
    maxfun_frec = parameters.maxfun;
else
    maxfun_frec = max(get_default_profile_options("maxfun"), ...
    get_default_profile_options("maxfun_factor")*parameters.problems_maxdim);
end

% Initialize fmin and frec.
num_solvers = length(parameters.solvers_options);
% Get number of problems.
num_problems = length(problem_names); 
% Get Number of random tests(If num_random = 1, it means no random test).
num_random = parameters.num_random; 
% Record minimum value of the problems of the random test.
fmin = NaN(num_problems, num_random);
frec = NaN(num_problems, num_solvers, num_random, maxfun_frec);

% Set noisy parts of test.
test_options.is_noisy = parameters.is_noisy;
test_options.noise_level = parameters.noise_level;
% Relative: (1+noise_level*noise)*f; absolute: f+noise_level*noise
test_options.is_abs_noise = parameters.is_abs_noise;
test_options.noise_type = parameters.noise_type;
test_options.num_random = parameters.num_random;

% Set scaling matrix.
test_options.scale_variable = false;

% Set solvers_options.
solvers_options = parameters.solvers_options;

% If parameters.noise_initial_point is true, then initial point will be 
% selected for each problem num_random times.
% parameters.fmintype is set to be "randomized" defaultly, then there is
% no need to test without noise, which makes the curve of performance profile
% more higher. If parallel is true, use parfor to calculate (parallel computation), 
% otherwise, use for to calculate (sequential computation).
if parameters.parallel == true
    parfor i_problem = 1:num_problems
        p = macup(problem_names(1, i_problem));
        % We must create a local copy of the part of frec that is modified
        % by the current loop because otherwise, MATLAB complains that it
        % does not understand which part should be parallelized.
        frec_local = NaN(num_solvers,num_random,maxfun_frec);
        for i_run = 1:num_random
            if parameters.random_initial_point
                rr = randn(size(x0));
                rr = rr / norm(rr);
                p.x0 = p.x0 + 1e-3 * max(1, norm(p.x0)) * rr;
            end
            fprintf("%d(%d). %s\n", i_problem, i_run, p.name);
            for i_solver = 1:num_solvers
                frec_local(i_solver,i_run,:) = get_fhist(p, maxfun_frec,...
                    i_solver, i_run, solvers_options, test_options);
            end
            fmin(i_problem,i_run) = min(frec_local(:,i_run,:),[],"all");
        end
        frec(i_problem,:,:,:) = frec_local;
    end
else
    for i_problem = 1:num_problems
        p = macup(problem_names(1, i_problem));
        frec_local = NaN(num_solvers,num_random,maxfun_frec);
        for i_run = 1:num_random
            if parameters.random_initial_point
                rr = randn(size(x0));
                rr = rr / norm(rr);
                p.x0 = p.x0 + 1e-3 * max(1, norm(p.x0)) * rr;
            end
            fprintf("%d(%d). %s\n", i_problem, i_run, p.name);
            for i_solver = 1:num_solvers
                frec_local(i_solver,i_run,:) = get_fhist(p, maxfun_frec,...
                    i_solver, i_run, solvers_options, test_options);
            end
            fmin(i_problem,i_run) = min(frec_local(:,i_run,:),[],"all");
        end
        frec(i_problem,:,:,:) = frec_local;
    end
end

% If parameters.fmintype = "real-randomized", then test without noise
% should be conducted and fmin might be smaller, which makes curves
%  of performance profile more lower.
if test_options.is_noisy && strcmpi(parameters.fmin_type, "real-randomized")
    fmin_real = NaN(num_problems, 1);
    test_options.is_noisy = false;
    i_run = 1;
    if parameters.parallel == true
        parfor i_problem = 1:num_problems
            p = macup(problem_names(1, i_problem));
            frec_local = NaN(num_solvers, maxfun_frec);
            if parameters.random_initial_point
                rr = randn(size(x0));
                rr = rr / norm(rr);
                p.x0 = p.x0 + 1e-3 * max(1, norm(p.x0)) * rr;
            end
            fprintf("%d. %s\n", i_problem, p.name);
            for i_solver = 1:num_solvers
                frec_local(i_solver,:) = get_fhist(p, maxfun_frec,...
                    i_solver, i_run, solvers_options, test_options);
            end
            fmin_real(i_problem) = min(frec_local(:, :),[],"all");
        end
    else
        for i_problem = 1:num_problems
            p = macup(problem_names(1, i_problem));
            frec_local = NaN(num_solvers, maxfun_frec);
            if parameters.random_initial_point
                rr = randn(size(x0));
                rr = rr / norm(rr);
                p.x0 = p.x0 + 1e-3 * max(1, norm(p.x0)) * rr;
            end
            fprintf("%d. %s\n", i_problem, p.name);
            for i_solver = 1:num_solvers
                frec_local(i_solver,:) = get_fhist(p, maxfun_frec,...
                    i_solver, i_run, solvers_options, test_options);
            end
            fmin_real(i_problem) = min(frec_local(:, :),[],"all");
        end
    end
end 

if strcmpi(parameters.fmin_type, "real-randomized")
    fmin_total = [fmin, fmin_real];
    fmin = min(fmin_total, [], 2);
end

% Use time to distinguish.
time = datetime("now");
time_str = sprintf('%04d-%02d-%02d %02d:%02d:%02.0f', year(time), ...
    month(time), day(time), hour(time), minute(time), second(time));
% Trim time string.
time_str = trim_time(time_str); 
tst = sprintf("test_%s", time_str); 
% Rename tst as mixture of time stamp and pdfname.
tst = strcat(tst, "_", parameters.pdfname);
path_testdata = fullfile(path_tests, "testdata");
path_testdata_outdir = fullfile(path_tests, "testdata", tst);

% Make a new folder to save numerical results and source code.
mkdir(path_testdata, tst);
mkdir(path_testdata_outdir, "perf");
options_perf.outdir = fullfile(path_testdata_outdir, "perf");
mkdir(path_testdata_outdir, "src");
path_testdata_src = fullfile(path_testdata_outdir, "src");
mkdir(path_testdata_outdir, "tests");
path_testdata_tests = fullfile(path_testdata_outdir, "tests");
path_testdata_competitors = fullfile(path_testdata_tests, "competitors");
mkdir(path_testdata_competitors);
path_testdata_private = fullfile(path_testdata_tests, "private");
mkdir(path_testdata_private);

% Copy the source code and test code to path_outdir.
copyfile(fullfile(path_src, "*"), path_testdata_src);
copyfile(fullfile(path_competitors, "*"), path_testdata_competitors);
copyfile(fullfile(path_tests, "private", "*"), path_testdata_private);

source_folder = path_tests;
destination_folder = path_testdata_tests;

% Get all files in the source folder.
file_list = dir(fullfile(source_folder, '*.*'));
file_list = file_list(~[file_list.isdir]);

% Copy all files (excluding subfolders) to the destination folder.
for i = 1:numel(file_list)
    source_file = fullfile(source_folder, file_list(i).name);
    destination_file = fullfile(destination_folder, file_list(i).name);
    copyfile(source_file, destination_file);
end

% Draw performance profiles.
% Set tolerance of convergence test in performance profile.
tau = parameters.tau; 
tau_length = length(tau);
options_perf.time_stamp = time_str;
options_perf.solvers = parameters.solvers_legend;
options_perf.natural_stop = false;
 
for l = 1:tau_length
    options_perf.tau = tau(l);
    output = perfprof(frec, fmin, options_perf);
end

cd(options_perf.outdir);

% Initialize string variable.
pdfFiles = dir(fullfile(options_perf.outdir, '*.pdf'));

% Store filename in a cell.
pdfNamesCell = cell(numel(pdfFiles), 1);
for i = 1:numel(pdfFiles)
    pdfNamesCell{i} = pdfFiles(i).name;
end

% Use the strjoin function to concatenate the elements in a cell array into a single string.
inputfiles = strjoin(pdfNamesCell, ' ');

% Remove spaces at the beginning of a string.
inputfiles = strtrim(inputfiles);

% Merge pdf.
outputfile = 'all.pdf';
system(['bash ', fullfile(path_tests, 'private', 'compdf'), ' ', inputfiles, ' -o ', outputfile]);
% Rename pdf.
movefile("all.pdf", sprintf("%s.pdf", parameters.pdfname));

% Restore the path to oldpath.
setpath(oldpath);  
% Go back to the original directory.
cd(old_dir);

end