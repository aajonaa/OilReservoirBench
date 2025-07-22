%% Modern Oil Reservoir Optimization Research Benchmark - Enhanced Version
%
% Research-standard implementation of the Egg Model for oil reservoir
% production optimization using modern MRST-2024b with multiple optimizers,
% statistical analysis, convergence tracking, and professional visualization.
%
% This enhanced benchmark follows the original Egg Model specifications for
% authentic research results comparable to published literature.
%
% FEATURES:
% - Multiple independent runs for statistical analysis
% - Multiple optimizer support framework
% - Convergence curve tracking and visualization
% - Professional figure beautification
% - Excel export with detailed results
% - Organized result directory structure
%
% REFERENCE:
%   Jansen, J.D., et al. (2014). "The egg model - a geological ensemble for
%   reservoir simulation." Geoscience Data Journal, 1(2), 192-195.

clear; clc; close all;
warning('off', 'all');

fprintf('=== ENHANCED OIL RESERVOIR OPTIMIZATION RESEARCH BENCHMARK ===\n');
fprintf('Multi-optimizer framework with statistical analysis (MRST-2024b)\n\n');

%% Step 1: Setup Modern Egg Model
fprintf('Step 1: Setting up modern Egg Model...\n');
try
    [G, rock, fluid, model, state0, W, schedule, nonlinear] = setupEggModel();
    fprintf('✓ Modern Egg Model setup complete\n\n');
catch ME
    error('Failed to setup Egg Model: %s', ME.message);
end

%% Step 2: Define Enhanced Experimental Settings
fprintf('Step 2: Defining enhanced experimental settings...\n');

% Problem dimensions (keep original Egg Model specifications)
nInjectors = 8;        % Number of injection wells
nTimeSteps = 6;        % Number of time periods (research standard)
nDim = nInjectors * nTimeSteps;  % Total decision variables (40)

% Enhanced experimental parameters
nRuns = 1;             % Independent runs for statistical analysis
maxFEs = 1000;         % Total function evaluations (increased for research)
popSize = 100;         % Population size

% Economic parameters (research standard)
economicParams = struct();
economicParams.ro = 20;           % Oil revenue ($/STB)
economicParams.rw = 1;            % Water production cost ($/STB)
economicParams.ri = 3;            % Water injection cost ($/STB)
economicParams.deltaT = 30;      % Time step duration (days)
economicParams.nTimeSteps = nTimeSteps;

% Optimization bounds (m³/day)
lb = zeros(1, nDim);              % Lower bounds: 0 m³/day
ub = 79.5 * ones(1, nDim);        % Upper bounds: 79.5 m³/day (500 STB/day)

% List of optimizers to test (expandable framework)
optimizers = {'runDESO', 'runSHPSO'};  % Start with SHPSO, easily expandable

fprintf('  Problem dimension: %d variables\n', nDim);
fprintf('  Injection bounds: [%.1f, %.1f] m³/day\n', lb(1), ub(1));
fprintf('  Time horizon: %d steps × %d days = %d days\n', ...
        nTimeSteps, economicParams.deltaT, nTimeSteps * economicParams.deltaT);
fprintf('  Economic params: Oil $%.0f/STB, Water $%.0f/STB, Injection $%.0f/STB\n', ...
        economicParams.ro, economicParams.rw, economicParams.ri);
fprintf('  Experimental setup: %d runs × %d FEs = %d total evaluations\n', ...
        nRuns, maxFEs, nRuns * maxFEs);
fprintf('  Optimizers: %s\n', strjoin(optimizers, ', '));
fprintf('✓ Enhanced experimental settings defined\n\n');

%% Step 3: Create Objective Function
fprintf('Step 3: Creating objective function...\n');

% Create function handle for NPV evaluation with AMGCL solver
objectiveFunction = @(x) evaluateNPV(x, G, rock, fluid, model, state0, W, economicParams, nonlinear, schedule);

% Test objective function with random solution
fprintf('  Testing objective function...\n');
testSolution = lb + rand(1, nDim) .* (ub - lb);
try
    testNPV = objectiveFunction(testSolution);
    fprintf('  Test NPV: $%.2e\n', testNPV);
    fprintf('✓ Objective function working\n\n');
catch ME
    error('Objective function test failed: %s', ME.message);
end

%% Step 4: Setup Result Directory Structure
fprintf('Step 4: Setting up result directory structure...\n');

% Create timestamped directory for results
expTime = datetime();
[year, month, day] = ymd(expTime);
[hour, minute, ~] = hms(expTime);
dayStr = sprintf('%04d-%02d-%02d', year, month, day);
timeStr = sprintf('%02d_%02d', hour, minute);
dirName = fullfile('result', dayStr, [optimizers{1}, '-', timeStr]);

% Create directory if it doesn't exist
if ~exist(dirName, 'dir')
    mkdir(dirName);
end

fprintf('  Results directory: %s\n', dirName);
fprintf('✓ Directory structure ready\n\n');

%% Step 5: Run Enhanced Multi-Optimizer Experiments
fprintf('Step 5: Running enhanced multi-optimizer experiments...\n');
fprintf('This will run %d independent experiments for statistical analysis...\n\n', nRuns);

% Initialize result storage
allResults = zeros(length(optimizers), 5);  % [Mean, Std, Worst, Best, Runtime]
allConvergence = cell(length(optimizers), nRuns);  % Convergence data
allRunResults = cell(length(optimizers), 1);  % Individual run results

% Start total experiment timer
totalStartTime = tic;

% Loop over each optimizer
for alg = 1:length(optimizers)
    optimizerName = optimizers{alg};
    fprintf('\n====== Running %s ======\n', optimizerName);

    % Initialize results storage for this algorithm
    runResults = zeros(nRuns, 4);  % [Best NPV, Worst NPV, Mean NPV, Runtime]
    tempConvergence = cell(nRuns, 1);  % Temporary storage for convergence data

    % Run the optimizer nRuns times
    for run = 1:nRuns
        fprintf('Run %d/%d for %s\n', run, nRuns, optimizerName);

        % Reset NPV tracking for this optimization run
        resetNPVTracking(popSize);

        % Get the function handle for current algorithm
        algo_fhd = str2func(optimizerName);
        [bestNPV, worstNPV, meanNPV, runTime, convergence] = algo_fhd(popSize, maxFEs, lb, ub, objectiveFunction);

        % Store results for this algorithm and run
        runResults(run, :) = [bestNPV, worstNPV, meanNPV, runTime];
        convergence = convergence(1:maxFEs);
        tempConvergence{run} = convergence;

        fprintf('Algorithm: %s, Run: %d, Best NPV: %.4e\n', optimizerName, run, bestNPV);
    end

    % Store results back into the main cell arrays
    allConvergence(alg, :) = tempConvergence;
    allRunResults{alg} = runResults;

    % Compute statistics over the runs for the current optimizer
    meanNPV_overRuns = mean(runResults(:,1));
    stdNPV_overRuns  = std(runResults(:,1));
    worstNPV_overRuns = min(runResults(:,2));
    bestNPV_overRuns  = max(runResults(:,1));
    avgRunTime       = mean(runResults(:,4));

    % Save into overall results table
    allResults(alg,:) = [meanNPV_overRuns, stdNPV_overRuns, worstNPV_overRuns, bestNPV_overRuns, avgRunTime];
end

totalExperimentTime = toc(totalStartTime);

%% Step 6: Display Statistical Summary
fprintf('\n=== STATISTICAL SUMMARY RESULTS ===\n');
fprintf('=============================================================\n');
fprintf('Algorithm\tMean\t\tStd\t\tWorst\t\tBest\t\tRunning time\n');
for alg = 1:length(optimizers)
    fprintf('%s\t\t%.2e\t%.2e\t%.2e\t%.2e\t%.2e\n', ...
        optimizers{alg}, allResults(alg,1), allResults(alg,2), ...
        allResults(alg,3), allResults(alg,4), allResults(alg,5));
end
fprintf('=============================================================\n');
fprintf('Total experiment time: %.1f minutes\n', totalExperimentTime/60);
fprintf('Average time per run: %.1f minutes\n', totalExperimentTime/(60*nRuns*length(optimizers)));
fprintf('\n=== ENHANCED BENCHMARK COMPLETE ===\n');

%% Step 7: Generate Professional Convergence Plots
fprintf('\nStep 7: Generating professional convergence plots...\n');

% Prepare convergence data for plotting
algoNum = length(optimizers);
NumofRecord = maxFEs;
NumSample = 20;  % For sampled plots
sample_indices = round(linspace(1, maxFEs, NumSample));

% Initialize 3D matrix for convergence curves
cg_curves = zeros(algoNum, nRuns, NumofRecord);
for alg = 1:algoNum
    for run = 1:nRuns
        cg_curves(alg, run, :) = allConvergence{alg, run};
    end
end

% Calculate mean values for each algorithm
YValue = zeros(algoNum, NumofRecord);
if nRuns == 1
    for algo = 1:algoNum
        YValue(algo,:) = squeeze(cg_curves(algo,1,:))';
    end
else
    for algo = 1:algoNum
        for fe = 1:NumofRecord
            YValue(algo,fe) = mean(cg_curves(algo,:,fe));
        end
    end
end

% Create X-axis values
XValue = (0:NumofRecord-1) * (maxFEs/(NumofRecord-1));

% Set up figure with professional styling
figure('Position', [100, 100, 1000, 600]);
set(gcf, 'color', 'white');

% Define plotting styles
basic_linestyles = cellstr(char('-','-','-','-'));
basic_Markers = cellstr(char('<','s','>','d','^','v','p','h'));
MarkerEdgeColors = hsv(algoNum);
linestyles = repmat(basic_linestyles, ceil(algoNum/numel(basic_linestyles)), 1);
Markers = repmat(basic_Markers, ceil(algoNum/numel(basic_Markers)), 1);

% Plot convergence curves
for algo = algoNum:-1:1
    plot(XValue, YValue(algo,:), [linestyles{algo} Markers{algo}], ...
        'LineWidth', 1.5, ...
        'Color', MarkerEdgeColors(algo,:), ...
        'MarkerFaceColor', MarkerEdgeColors(algo,:), ...
        'MarkerSize', 4, ...
        'DisplayName', optimizers{algo});
    hold on;
end

hold off;
xlabel('FEs');
ylabel('NPV (USD)');
title('Oil Reservoir Optimization Convergence', 'FontWeight', 'normal');
legend('Location', 'southeast');

% Beautify the figure with professional styling
a = findobj(gcf);
allaxes = findall(a,'Type','axes');
alltext = findall(a,'Type','text');
set(allaxes,'FontName','Times New Roman','LineWidth',1,'FontSize',8);
set(alltext,'FontName','Times New Roman','FontSize',10);
set(gcf, 'PaperUnits', 'inches');

krare = 3;
figureWidth = krare*4/3;
figureHeight = krare*3/3;
set(gcf, 'PaperPosition', [0,0,figureWidth,figureHeight]);

set(gca, ...
    'Box', 'on', ...
    'TickDir', 'in', ...
    'TickLength', [.01 .01], ...
    'XTick', 0:200:maxFEs, ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'on', ...
    'YGrid', 'off', ...
    'XGrid', 'off', ...
    'XColor', [0 0 0], ...
    'YColor', [0 0 0], ...
    'LineWidth', 0.5);

axis tight;

% Save convergence plot
CCFigName = fullfile(dirName, [optimizers{1}, '-OilReservoir-CC']);
print(CCFigName, '-dtiff', '-r600');
saveas(gcf, CCFigName, 'fig');

fprintf('✓ Convergence plot saved: %s\n', CCFigName);

%% Step 8: Export Results to Excel
fprintf('\nStep 8: Exporting results to Excel...\n');

% Create Excel file path
outputPath = fullfile(dirName, 'OilReservoirResults.xlsx');

% Create statistical summary table
headers = {'Algorithm', 'Mean', 'Std', 'Worst', 'Best', 'Running_time'};
resultsTable = array2table(allResults, 'VariableNames', headers(2:end));
resultsTable.Algorithm = optimizers';
resultsTable = resultsTable(:, ['Algorithm', headers(2:end)]);

% Write statistical summary to Excel
writetable(resultsTable, outputPath, 'Sheet', 'Statistical_Summary');

% Create convergence data table
cgHeaders = ['FEs', optimizers];
cgData = [XValue' YValue'];
cgTable = array2table(cgData, 'VariableNames', cgHeaders);

% Write convergence data to Excel
writetable(cgTable, outputPath, 'Sheet', 'Convergence_Data');

% Create sampled convergence data for cleaner plots
XValue_sampled = linspace(0, maxFEs, NumSample);
YValue_sampled = zeros(algoNum, NumSample);
for algo = 1:algoNum
    YValue_sampled(algo,:) = YValue(algo, sample_indices);
end

cgHeadersSample = ['FEs', optimizers];
cgDataSample = [XValue_sampled' YValue_sampled'];
cgTableSample = array2table(cgDataSample, 'VariableNames', cgHeadersSample);

% Write sampled convergence data to Excel
writetable(cgTableSample, outputPath, 'Sheet', 'Convergence_Sampled');

fprintf('✓ Results exported to Excel: %s\n', outputPath);

%% Step 9: Save Complete Results Structure
fprintf('\nStep 9: Saving complete results structure...\n');

% Create comprehensive results structure
results = struct();
results.experimentInfo = struct();
results.experimentInfo.timestamp = datestr(now);
results.experimentInfo.nRuns = nRuns;
results.experimentInfo.maxFEs = maxFEs;
results.experimentInfo.popSize = popSize;
results.experimentInfo.optimizers = optimizers;

results.problemInfo = struct();
results.problemInfo.nDim = nDim;
results.problemInfo.nInjectors = nInjectors;
results.problemInfo.nTimeSteps = nTimeSteps;
results.problemInfo.bounds = [lb; ub];
results.problemInfo.economic = economicParams;

results.statisticalSummary = allResults;
results.convergenceData = allConvergence;
results.individualRuns = allRunResults;
results.totalExperimentTime = totalExperimentTime;

% Save to MAT file
resultsFile = fullfile(dirName, 'CompleteResults.mat');
save(resultsFile, 'results');

fprintf('✓ Complete results saved: %s\n', resultsFile);
fprintf('\n=== ENHANCED BENCHMARK COMPLETE ===\n');
fprintf('All results, plots, and data have been saved to: %s\n', dirName);
fprintf('Ready for comprehensive research analysis!\n');
