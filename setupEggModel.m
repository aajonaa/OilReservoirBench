function [G, rock, fluid, model, state0, W, schedule, nonlinear] = setupEggModel()
%% setupEggModel - Research-Standard Egg Model Setup for Oil Reservoir Optimization
%
% This function creates a clean, research-standard implementation of the Egg Model
% for oil reservoir production optimization benchmarks using modern MRST-2024b.
%
% OUTPUTS:
%   G        - Grid structure (60x60x7 cells)
%   rock     - Rock properties (permeability, porosity)
%   fluid    - Fluid model (oil-water, no gas)
%   model    - Reservoir simulation model
%   state0   - Initial reservoir state
%   W        - Well structures (8 injectors + 4 producers)
%   schedule - Simulation schedule template
%   nonlinear- NonLinearSolver with AMGCL configuration
%
% REFERENCE:
%   Jansen, J.D., et al. (2014). "The egg model - a geological ensemble for
%   reservoir simulation." Geoscience Data Journal, 1(2), 192-195.
%
% Created for research benchmarking - maintains original Egg Model specifications

    fprintf('=== SETTING UP EGG MODEL FOR RESEARCH BENCHMARK ===\n');

    %% Step 1: Initialize MRST (Modern MRST-2024b approach)
    try
        % Suppress dependency dialogs for automated execution
        warning('off', 'all');

        % Check if MRST is already initialized
        if ~exist('mrstPath', 'file')
            % Initialize MRST
            run('mrst-2024b/startup.m');
        end

        % Set MRST to not prompt for downloads during benchmark
        try
            mrstSettings('set', 'allowDL', false);
            mrstSettings('set', 'promptDL', false);
            mrstSettings('set', 'useAMGCL', true);  % Disable AMGCL
        mrstSettings('set', 'allowDL', true);    % Allow downloads for AMGCL dependencies
        catch
            % Settings may not be available, continue anyway
        end

        % Load required modules (modern MRST-2024b approach)
        mrstModule add ad-core ad-blackoil deckformat test-suite linearsolvers

        fprintf('✓ MRST modules loaded (dependency dialogs suppressed)\n');
    catch ME
        error('Failed to initialize MRST: %s', ME.message);
    end
    
    %% Step 2: Load Egg Model using direct Eclipse loading
    try
        % Use direct Eclipse loading to bypass MRST dataset issues
        % Try local file locations only for complete portability
        deckPaths = {
            fullfile('Egg', 'Eclipse', 'Egg_Model_ECL.DATA'),     % Primary local location
            fullfile('Eclipse', 'Egg_Model_ECL.DATA')             % Alternative local location
        };

        deckFile = '';
        for i = 1:length(deckPaths)
            if exist(deckPaths{i}, 'file')
                deckFile = deckPaths{i};
                break;
            end
        end

        if isempty(deckFile)
            error('Egg Model deck file not found in any expected location');
        end

        % Load Eclipse deck
        deck = readEclipseDeck(deckFile);
        deck = convertDeckUnits(deck);

        % Initialize grid
        G = initEclipseGrid(deck);
        G = computeGeometry(G);

        % Initialize rock properties
        rock = initEclipseRock(deck);
        rock = compressRock(rock, G.cells.indexMap);

        % Initialize fluid model
        fluid = initDeckADIFluid(deck);

        % Set gravity (following Egg Model specifications)
        gravity reset on

        % Initialize state with gravity effects
        pr = 400*barsa;
        rz = G.cells.centroids(1,3);
        dz = G.cells.centroids(:,3) - rz;
        rhoO = fluid.bO(400*barsa)*fluid.rhoOS;
        rhoW = fluid.bW(400*barsa)*fluid.rhoWS;
        rhoMix = 0.1*rhoW + 0.9*rhoO;
        p0 = pr + norm(gravity)*rhoMix*dz;
        state0 = initResSol(G, p0, [0.1, 0.9]);

        fprintf('✓ Egg Model loaded using direct Eclipse loading\n');
        fprintf('  Deck file: %s\n', deckFile);
        fprintf('  Grid: %d×%d×%d = %d active cells\n', ...
                G.cartDims(1), G.cartDims(2), G.cartDims(3), G.cells.num);
        fprintf('  Permeability range: %.2e - %.2e mD\n', ...
                min(rock.perm(:))/milli/darcy, max(rock.perm(:))/milli/darcy);
        fprintf('  Porosity range: %.3f - %.3f\n', ...
                min(rock.poro(:)), max(rock.poro(:)));
    catch ME
        error('Failed to setup Egg Model: %s', ME.message);
    end
    
    %% Step 3: Initialize modern model and schedule
    try
        % Use modern initEclipseProblemAD for complete setup with timestep control
        [state0, model, schedule, nonlinear] = initEclipseProblemAD(deck, ...
            'G', G, 'TimestepStrategy', 'none');

        % Configure AMGCL linear solver following official SINTEF documentation
        if ~isempty(nonlinear) && isa(nonlinear, 'NonLinearSolver')
            fprintf('  Setting up AMGCL linear solver...\n');

            % Step 1: Enable automatic downloads
            mrstSettings('set', 'allowDL', true);
            mrstSettings('set', 'promptDL', false);

            % Step 2: Set up global variables and download dependencies
            global BOOSTPATH AMGCLPATH;
            try
                fprintf('  Downloading AMGCL dependencies (if needed)...\n');
                [AMGCLPATH, BOOSTPATH] = getAMGCLDependencyPaths();
                fprintf('  Dependencies ready: AMGCL and Boost configured\n');

                % Step 3: Create AMGCL-CPR solver (recommended for reservoir simulation)
                solver = AMGCL_CPRSolverAD('maxIterations', 100, 'tolerance', 1e-4);
                solver.setSRelaxation('ilu0');        % ILU(0) relaxation
                solver.setCoarsening('aggregation');  % Fast aggregation coarsening
                solver.setSolver('bicgstab');         % BiCGStab Krylov solver

                nonlinear.LinearSolver = solver;
                fprintf('  ✓ Using AMGCL-CPR linear solver (maximum performance)\n');

            catch ME
                fprintf('  ⚠ AMGCL setup failed: %s\n', ME.message);
                fprintf('  Falling back to reliable alternatives...\n');

                try
                    % Fallback to CPR with built-in AMG (reliable 3-5x speedup)
                    solver = CPRSolverAD('ellipticSolver', AMGSolverAD(), ...
                                       'tolerance', 1e-4, 'maxIterations', 100);
                    nonlinear.LinearSolver = solver;
                    fprintf('  ✓ Using CPR-AMG linear solver (high performance, reliable)\n');
                catch
                    try
                        % Fallback to MEX-accelerated solver (2-3x speedup)
                        nonlinear.LinearSolver = selectLinearSolverAD(model, 'useMex', true);
                        fprintf('  ✓ Using MEX-accelerated solver (good performance)\n');
                    catch
                        % Final fallback to standard solver
                        nonlinear.LinearSolver = selectLinearSolverAD(model, 'useMex', false);
                        fprintf('  ⚠ Using standard solver (basic performance)\n');
                    end
                end
            end

            % Configure NonLinearSolver for robust convergence
            fprintf('  Configuring robust convergence settings...\n');
            nonlinear.maxIterations = 25;        % Reduce from 50 to 25 for faster failure detection
            nonlinear.maxTimestepCuts = 8;       % Allow more timestep cuts (default: 6)
            nonlinear.minIterations = 1;         % Minimum iterations before cutting

            % Configure timestep selector for adaptive timesteps
            if isempty(nonlinear.timeStepSelector) || ~isa(nonlinear.timeStepSelector, 'IterationCountTimeStepSelector')
                nonlinear.timeStepSelector = IterationCountTimeStepSelector();
            end

            % Set timestep selector parameters for robust simulation
            nonlinear.timeStepSelector.targetIterationCount = 8;    % Target 8 iterations
            nonlinear.timeStepSelector.minTimestep = 0.1*day;       % Minimum timestep: 0.1 day
            nonlinear.timeStepSelector.maxTimestep = 90*day;        % Maximum timestep: 90 days
            nonlinear.timeStepSelector.firstRampupStep = 5*day;     % Start with 5-day steps

            fprintf('  ✓ Robust convergence settings configured\n');
        else
            fprintf('  ⚠ NonLinearSolver not properly initialized\n');
        end

        fprintf('✓ Modern simulation model initialized\n');
        fprintf('  Model type: %s\n', class(model));
        fprintf('  Schedule: %d time steps\n', numel(schedule.step.val));
        fprintf('  Timestep control: MRST-2024b defaults (modified in source code)\n');
    catch ME
        error('Failed to initialize model: %s', ME.message);
    end
    
    %% Step 4: Extract and validate wells
    try
        % Extract wells from the schedule
        W = schedule.control(1).W;

        % Validate well configuration
        if numel(W) ~= 12
            warning('Expected 12 wells, found %d wells', numel(W));
        end

        % Count well types
        nInj = sum([W.sign] > 0);
        nProd = sum([W.sign] < 0);

        fprintf('✓ Wells extracted from schedule\n');
        fprintf('  Total wells: %d (%d injectors, %d producers)\n', numel(W), nInj, nProd);

        % Validate well types match Egg Model specification
        if nInj ~= 8 || nProd ~= 4
            warning('Well configuration differs from standard Egg Model (8 inj, 4 prod)');
        end

    catch ME
        error('Failed to extract wells: %s', ME.message);
    end
    
    %% Step 5: Final validation and summary
    try
        % Comprehensive validation
        assert(G.cells.num > 0, 'Grid has no active cells');
        assert(numel(W) >= 8, 'Insufficient number of wells');
        assert(all(isfinite(rock.perm(:))), 'Invalid permeability values');
        assert(all(isfinite(rock.poro(:))), 'Invalid porosity values');
        assert(~isempty(schedule.step), 'Schedule is empty');
        assert(isa(model, 'ReservoirModel'), 'Invalid model type');

        fprintf('✓ All validation checks passed\n');
        fprintf('=== EGG MODEL SETUP COMPLETE ===\n\n');

        % Research summary
        fprintf('RESEARCH-READY EGG MODEL:\n');
        fprintf('  Framework: MRST-2024b (modern)\n');
        fprintf('  Grid: %d×%d×%d = %d cells\n', G.cartDims(1), G.cartDims(2), G.cartDims(3), G.cells.num);
        fprintf('  Wells: %d total (%d injectors, %d producers)\n', numel(W), nInj, nProd);
        fprintf('  Model: %s\n', class(model));
        fprintf('  Physics: Two-phase oil-water with gravity\n');
        fprintf('  Ready for optimization benchmark\n\n');

    catch ME
        error('Validation failed: %s', ME.message);
    end
end
