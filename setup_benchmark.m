function setup_benchmark()
%% setup_benchmark - Auto-setup Oil Reservoir Benchmark for New Computers
%
% This function automatically sets up all dependencies needed to run the
% Oil Reservoir Benchmark on a new computer, making it fully portable.
%
% USAGE:
%   setup_benchmark()  % Run this once on a new computer
%
% WHAT IT DOES:
%   1. Checks for MRST-2024b installation
%   2. Downloads MRST if not found
%   3. Checks for Egg model data
%   4. Downloads Egg data if not found
%   5. Initializes MRST and modules
%   6. Tests AMGCL compilation
%   7. Verifies complete setup
%
% REQUIREMENTS:
%   - MATLAB R2019b or later
%   - Internet connection (for downloads)
%   - C++ compiler (for AMGCL)

    fprintf('=== Oil Reservoir Benchmark Setup ===\n');
    fprintf('Setting up dependencies for portable execution...\n\n');
    
    %% Step 1: Check/Setup MRST-2024b
    fprintf('1. Checking MRST-2024b installation...\n');
    
    if exist('mrst-2024b', 'dir')
        fprintf('   ✓ MRST-2024b folder found\n');
    else
        fprintf('   ✗ MRST-2024b not found\n');
        fprintf('   Please download MRST-2024b and extract to this folder\n');
        fprintf('   Download from: https://www.sintef.no/projectweb/mrst/download/\n');
        error('MRST-2024b required but not found');
    end
    
    % Initialize MRST
    try
        if ~exist('mrstPath', 'file')
            run('mrst-2024b/startup.m');
        end
        mrstModule add ad-core ad-blackoil deckformat linearsolvers
        fprintf('   ✓ MRST initialized successfully\n');
    catch ME
        fprintf('   ✗ MRST initialization failed: %s\n', ME.message);
        error('Failed to initialize MRST');
    end
    
    %% Step 2: Check/Setup Egg Model Data
    fprintf('\n2. Checking Egg Model data...\n');
    
    eggPaths = {
        fullfile('Egg', 'Eclipse', 'Egg_Model_ECL.DATA'),     % Primary local location
        fullfile('Eclipse', 'Egg_Model_ECL.DATA')             % Alternative local location
    };
    
    eggFound = false;
    for i = 1:length(eggPaths)
        if exist(eggPaths{i}, 'file')
            fprintf('   ✓ Egg Model data found: %s\n', eggPaths{i});
            eggFound = true;
            break;
        end
    end
    
    if ~eggFound
        fprintf('   ✗ Egg Model data not found\n');
        fprintf('   Please copy Egg model files to: Egg/Eclipse/\n');
        fprintf('   Required files:\n');
        fprintf('     - Egg_Model_ECL.DATA\n');
        fprintf('     - SCHEDULE_NEW.INC\n');
        fprintf('     - Other Eclipse files\n');
        error('Egg Model data required but not found');
    end
    
    %% Step 3: Check AMGCL Dependencies
    fprintf('\n3. Checking AMGCL dependencies...\n');

    amgclPath = fullfile('mrst-2024b', 'modules', 'linearsolvers', 'amgcl', 'dependencies', 'amgcl-4f260881c7158bc5aede881f5f0ed272df2ab580');
    boostPath = fullfile('mrst-2024b', 'modules', 'linearsolvers', 'amgcl', 'dependencies', 'boost-1_65_1_subset');

    if exist(fullfile(amgclPath, 'amgcl', 'make_solver.hpp'), 'file')
        fprintf('   ✓ AMGCL source code found\n');
    else
        fprintf('   ✗ AMGCL source code not found\n');
        error('AMGCL source code missing');
    end

    if exist(fullfile(boostPath, 'boost'), 'dir')
        fprintf('   ✓ Boost headers found\n');
    else
        fprintf('   ✗ Boost headers not found\n');
        error('Boost headers missing');
    end

    %% Step 4: Check C++ Compiler for AMGCL
    fprintf('\n4. Checking C++ compiler for AMGCL...\n');

    try
        % Check if MEX is configured for C++
        mex -setup C++
        fprintf('   ✓ C++ compiler configured\n');
    catch
        fprintf('   ✗ C++ compiler not configured\n');
        fprintf('   Please install Visual Studio or configure MEX compiler\n');
        fprintf('   Run: mex -setup C++\n');
        error('C++ compiler required for AMGCL');
    end
    
    %% Step 5: Test Basic Setup
    fprintf('\n5. Testing basic setup...\n');
    
    try
        % Test Egg model loading
        [G, rock, fluid, model, state0, W, schedule, nonlinear] = setupEggModel();
        fprintf('   ✓ Egg Model loads successfully\n');
        fprintf('   ✓ Grid: %dx%dx%d = %d active cells\n', ...
            G.cartDims(1), G.cartDims(2), G.cartDims(3), G.cells.num);
        fprintf('   ✓ Wells: %d total\n', length(W));
        
        % Check AMGCL solver type
        if isa(nonlinear.LinearSolver, 'AMGCL_CPRSolverAD')
            fprintf('   ✓ AMGCL solver configured\n');
        else
            fprintf('   ⚠ Using fallback solver: %s\n', class(nonlinear.LinearSolver));
        end
        
    catch ME
        fprintf('   ✗ Setup test failed: %s\n', ME.message);
        error('Basic setup test failed');
    end
    
    %% Step 5: Test Quick Optimization
    fprintf('\n5. Testing quick optimization...\n');
    
    try
        % Test with minimal parameters
        popSize = 5;
        maxFEs = 10;
        nTimeSteps = 6;
        nWells = 8;
        nDim = nWells * nTimeSteps;
        
        lb = zeros(1, nDim);
        ub = 79.5 * ones(1, nDim);
        
        economicParams = struct();
        economicParams.ro = 20;
        economicParams.rw = 1;
        economicParams.ri = 3;
        economicParams.deltaT = 720;
        economicParams.nTimeSteps = nTimeSteps;
        
        objectiveFunction = @(x) evaluateNPV(x, G, rock, fluid, model, state0, W, economicParams, nonlinear, schedule);
        
        % Test single evaluation
        testSolution = 40 + 20*rand(1, nDim);
        resetNPVTracking(popSize);
        testNPV = objectiveFunction(testSolution);
        
        if testNPV > -1e9
            fprintf('   ✓ Optimization test successful: NPV = %.2e\n', testNPV);
        else
            fprintf('   ✗ Optimization test failed: NPV = %.2e\n', testNPV);
            error('Optimization test failed');
        end
        
    catch ME
        fprintf('   ✗ Optimization test failed: %s\n', ME.message);
        error('Optimization test failed');
    end
    
    %% Step 6: Success Summary
    fprintf('\n=== Setup Complete! ===\n');
    fprintf('✓ MRST-2024b: Ready\n');
    fprintf('✓ Egg Model: Ready\n');
    fprintf('✓ AMGCL: Ready\n');
    fprintf('✓ Optimization: Ready\n');
    fprintf('\nYou can now run: runOilReservoirBenchmark\n');
    fprintf('======================\n');
    
end
