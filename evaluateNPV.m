function npv = evaluateNPV(injectionRates, G, rock, fluid, model, state0, W, economicParams)
%% evaluateNPV - Modern NPV Evaluation for Oil Reservoir Optimization
%
% This function evaluates the Net Present Value (NPV) for a given set of
% injection rates using the modern MRST-2024b Egg Model simulation.
%
% INPUTS:
%   injectionRates - Vector of injection rates [m³/day] (40 elements: 8 wells × 5 time steps)
%   G              - Grid structure
%   rock           - Rock properties
%   fluid          - Fluid model
%   model          - Reservoir simulation model
%   state0         - Initial reservoir state
%   W              - Well structures
%   economicParams - Economic parameters structure with fields:
%                    .ro (oil revenue $/STB)
%                    .rw (water production cost $/STB)
%                    .ri (water injection cost $/STB)
%                    .deltaT (time step duration in days)
%                    .nTimeSteps (number of time steps)
%
% OUTPUT:
%   npv - Net Present Value [$USD]
%
% FORMULA:
%   NPV = Σ(t=1 to nTimeSteps) deltaT × [ro×Qo,t - rw×Qw,t - ri×Qi,t]
%
% REFERENCE:
%   Jansen, J.D., et al. (2014). "The egg model - a geological ensemble for
%   reservoir simulation." Geoscience Data Journal, 1(2), 192-195.

    try
        % Suppress warnings for cleaner output
        warning('off', 'all');
        
        %% Extract parameters
        ro = economicParams.ro;           % Oil revenue ($/STB)
        rw = economicParams.rw;           % Water production cost ($/STB)
        ri = economicParams.ri;           % Water injection cost ($/STB)
        deltaT = economicParams.deltaT;   % Time step duration (days)
        nTimeSteps = economicParams.nTimeSteps;  % Number of time steps
        nInjectors = 8;                   % Number of injection wells
        
        % Unit conversion factors
        m3_day_to_stb_day = 6.28981;      % m³/day to STB/day conversion
        
        %% Validate inputs
        expectedLength = nInjectors * nTimeSteps;
        if length(injectionRates) ~= expectedLength
            error('Expected %d injection rates, got %d', expectedLength, length(injectionRates));
        end
        
        % Reshape injection rates: [nInjectors × nTimeSteps]
        rates = reshape(injectionRates, nInjectors, nTimeSteps);
        
        % Validate injection rates are within reasonable bounds
        if any(rates(:) < 0) || any(rates(:) > 200)  % 200 m³/day = ~1260 STB/day
            npv = -1e10;  % Penalty for invalid rates
            return;
        end
        
        %% Create simulation schedule
        schedule = struct();
        schedule.control = repmat(struct('W', W), nTimeSteps, 1);
        schedule.step = struct();
        schedule.step.val = deltaT * day * ones(nTimeSteps, 1);  % Convert days to seconds
        schedule.step.control = (1:nTimeSteps)';
        
        % Update injection rates for each time step
        for t = 1:nTimeSteps
            W_t = W;  % Copy well structure
            
            % Set injection rates for this time step
            for i = 1:nInjectors
                W_t(i).val = rates(i, t);     % Injection rate (m³/day)
                W_t(i).type = 'rate';         % Rate control
                W_t(i).compi = [1, 0];        % Pure water injection
                
                % Original pressure limit from Eclipse
                if ~isfield(W_t(i), 'lims')
                    W_t(i).lims = struct();
                end
                W_t(i).lims.bhp = 420*barsa;  % Maximum injection pressure
            end
            
            % Production wells keep original BHP control
            for i = (nInjectors+1):numel(W_t)
                W_t(i).type = 'bhp';
                W_t(i).val = 395*barsa;       % Production BHP
                W_t(i).compi = [0, 1];        % Expect oil production
                % No rate limits (original specification)
            end
            
            schedule.control(t).W = W_t;
        end
        
        %% Run reservoir simulation (Modern MRST-2024b approach)
        try
            % Run simulation with modified MRST defaults (timestep control in source code)
            [wellSols, states] = simulateScheduleAD(state0, model, schedule, 'Verbose', true);

            if isempty(wellSols) || length(wellSols) < nTimeSteps
                npv = -1e10;  % Penalty for simulation failure
                return;
            end

        catch ME
            % Simulation failed - return penalty
            npv = -1e10;
            return;
        end
        
        %% Calculate NPV with simplified logging
        npv = 0;

        fprintf('Timestep NPVs: ');

        for t = 1:nTimeSteps
            if t > length(wellSols)
                break;  % Simulation didn't complete all time steps
            end

            wellSol = wellSols{t};

            % Extract production rates (m³/day)
            Qo_total = 0;  % Total oil production
            Qw_total = 0;  % Total water production
            Qi_total = 0;  % Total water injection

            for i = 1:numel(wellSol)
                if i <= nInjectors
                    % Injection wells - try different field names
                    if isfield(wellSol(i), 'qWs')
                        Qi_total = Qi_total + max(0, wellSol(i).qWs);  % Water injection
                    elseif isfield(wellSol(i), 'qLs')
                        Qi_total = Qi_total + max(0, wellSol(i).qLs);  % Total liquid
                    end
                else
                    % Production wells - try different field names
                    if isfield(wellSol(i), 'qOs')
                        Qo_total = Qo_total + max(0, -wellSol(i).qOs); % Oil production (negative sign)
                    end
                    if isfield(wellSol(i), 'qWs')
                        Qw_total = Qw_total + max(0, -wellSol(i).qWs); % Water production (negative sign)
                    elseif isfield(wellSol(i), 'qLs') && isfield(wellSol(i), 'qOs')
                        Qw_total = Qw_total + max(0, -(wellSol(i).qLs - wellSol(i).qOs)); % Water = Total - Oil
                    end
                end
            end
            
            % Convert from m³/s (MRST units) to STB/day
            % MRST well rates are in m³/s, need to convert to m³/day first, then to STB/day
            seconds_per_day = 86400;  % 24 * 60 * 60
            Qo_stb = Qo_total * seconds_per_day * m3_day_to_stb_day;  % m³/s → m³/day → STB/day
            Qw_stb = Qw_total * seconds_per_day * m3_day_to_stb_day;  % m³/s → m³/day → STB/day
            Qi_stb = Qi_total * seconds_per_day * m3_day_to_stb_day;  % m³/s → m³/day → STB/day
            
            % Calculate cash flow for this time step
            revenue = ro * Qo_stb;                    % Oil revenue
            water_cost = rw * Qw_stb;                 % Water production cost
            injection_cost = ri * Qi_stb;             % Water injection cost

            cash_flow = revenue - water_cost - injection_cost;

            % Calculate NPV for this timestep
            timestep_npv = deltaT * cash_flow;

            % Add to NPV (no discounting in original formulation)
            npv = npv + timestep_npv;

            % Print only the timestep NPV value
            fprintf('$%.2e ', timestep_npv);
        end

        fprintf('| Total: $%.2e\n', npv);

        % Ensure NPV is finite
        if ~isfinite(npv)
            npv = -1e10;
        end

    catch ME
        % Any error results in penalty
        npv = -1e10;
    end
    
    % Restore warnings
    warning('on', 'all');
end
