%% Modern Oil Reservoir Optimization Research Benchmark
%
% Research-standard implementation of the Egg Model for oil reservoir
% production optimization using modern MRST-2024b and SHPSO optimizer.
%
% This benchmark follows the original Egg Model specifications for
% authentic research results comparable to published literature.
%
% REFERENCE:
%   Jansen, J.D., et al. (2014). "The egg model - a geological ensemble for
%   reservoir simulation." Geoscience Data Journal, 1(2), 192-195.

clear; clc; close all;

fprintf('=== MODERN OIL RESERVOIR OPTIMIZATION RESEARCH BENCHMARK ===\n');
fprintf('Using SHPSO optimizer with authentic Egg Model (MRST-2024b)\n\n');

%% Step 1: Setup Modern Egg Model
fprintf('Step 1: Setting up modern Egg Model...\n');
try
    [G, rock, fluid, model, state0, W, schedule] = setupEggModel();
    fprintf('✓ Modern Egg Model setup complete\n\n');
catch ME
    error('Failed to setup Egg Model: %s', ME.message);
end

%% Step 2: Define Optimization Problem
fprintf('Step 2: Defining optimization problem...\n');

% Problem dimensions
nInjectors = 8;        % Number of injection wells
nTimeSteps = 5;        % Number of time periods (research standard)
nDim = nInjectors * nTimeSteps;  % Total decision variables (40)

% Economic parameters (research standard)
economicParams = struct();
economicParams.ro = 20;           % Oil revenue ($/STB)
economicParams.rw = 1;            % Water production cost ($/STB)
economicParams.ri = 3;            % Water injection cost ($/STB)
economicParams.deltaT = 720;      % Time step duration (days)
economicParams.nTimeSteps = nTimeSteps;

% Optimization bounds (m³/day)
lb = zeros(1, nDim);              % Lower bounds: 0 m³/day
ub = 79.5 * ones(1, nDim);        % Upper bounds: 79.5 m³/day (500 STB/day)

fprintf('  Problem dimension: %d variables\n', nDim);
fprintf('  Injection bounds: [%.1f, %.1f] m³/day\n', lb(1), ub(1));
fprintf('  Time horizon: %d steps × %d days = %d days\n', ...
        nTimeSteps, economicParams.deltaT, nTimeSteps * economicParams.deltaT);
fprintf('  Economic params: Oil $%.0f/STB, Water $%.0f/STB, Injection $%.0f/STB\n', ...
        economicParams.ro, economicParams.rw, economicParams.ri);
fprintf('✓ Optimization problem defined\n\n');

%% Step 3: Create Objective Function
fprintf('Step 3: Creating objective function...\n');

% Create function handle for NPV evaluation
objectiveFunction = @(x) evaluateNPV(x, G, rock, fluid, model, state0, W, economicParams);

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

%% Step 4: Configure SHPSO Optimizer
fprintf('Step 4: Configuring SHPSO optimizer...\n');

% SHPSO parameters (research standard)
popSize = 100;          % Population size
maxFEs = 1000;         % Maximum function evaluations

fprintf('  Population size: %d\n', popSize);
fprintf('  Max evaluations: %d\n', maxFEs);
fprintf('  Expected runtime: ~30-60 minutes\n');
fprintf('✓ SHPSO configured\n\n');

%% Step 5: Run Optimization
fprintf('Step 5: Running SHPSO optimization...\n');
fprintf('This may take 30-60 minutes depending on your system...\n\n');

% Start optimization
startTime = tic;

try
    % Run SHPSO optimizer
    [bestNPV, worstNPV, meanNPV, runTime, convergence] = runSHPSO(popSize, maxFEs, lb, ub, objectiveFunction);
    
    totalTime = toc(startTime);
    
    fprintf('✓ Optimization complete!\n\n');
    
catch ME
    error('Optimization failed: %s', ME.message);
end

%% Step 6: Display Results
fprintf('=== OPTIMIZATION RESULTS ===\n');
fprintf('Best NPV:     $%.2e\n', bestNPV);
fprintf('Worst NPV:    $%.2e\n', worstNPV);
fprintf('Mean NPV:     $%.2e\n', meanNPV);
fprintf('Runtime:      %.1f minutes\n', totalTime/60);
fprintf('Evaluations:  %d\n', maxFEs);
fprintf('Avg per eval: %.1f seconds\n', totalTime/maxFEs);

% Performance metrics
improvement = (bestNPV - worstNPV) / abs(worstNPV) * 100;
fprintf('Improvement:  %.1f%%\n', improvement);

fprintf('\n=== BENCHMARK COMPLETE ===\n');
fprintf('Results are ready for research analysis\n');

%% Step 7: Save Results
fprintf('\nStep 7: Saving results...\n');

% Create results structure
results = struct();
results.bestNPV = bestNPV;
results.worstNPV = worstNPV;
results.meanNPV = meanNPV;
results.runTime = totalTime;
results.convergence = convergence;
results.parameters = struct();
results.parameters.popSize = popSize;
results.parameters.maxFEs = maxFEs;
results.parameters.nDim = nDim;
results.parameters.bounds = [lb; ub];
results.parameters.economic = economicParams;
results.timestamp = datestr(now);

% Save to file
resultsFile = sprintf('EggModel_SHPSO_Results_%s.mat', datestr(now, 'yyyy-mm-dd_HH-MM'));
save(resultsFile, 'results');

fprintf('✓ Results saved to: %s\n', resultsFile);
fprintf('\nBenchmark complete! Ready for research analysis.\n');
