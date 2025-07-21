function [cg_curve] = KTA2(N, MaxFEs, LB, UB, dim, fobj)
% KTA2 - Kriging assisted Two_Arch2 (Single-objective version)

% Parameter initialization
LB = repmat(LB, 1, dim);
UB = repmat(UB, 1, dim);

% Algorithm parameters
mu = 5;          % Number of re-evaluated solutions at each generation
wmax = 10;       % Number of generations before updating CA and DA
THETA_S = 5.*ones(1, dim);

% Initialize tracking variables
NFEs = 0;
cg_curve = zeros(1, MaxFEs);

% Generate initial population using Latin Hypercube Sampling
P = lhsdesign(N, dim);
Population.dec = repmat(LB, N, 1) + (repmat(UB - LB, N, 1)).*P;
Population.obj = fobj(Population.dec);
if size(Population.obj, 2) > 1
    Population.obj = Population.obj(:);
end

% Record initial evaluations
for i = 1:N    
    NFEs = NFEs + 1;
    cg_curve(1, NFEs) = min(Population.obj(1:i));
end

% Initialize archives and training data
Training_data = Population;
[~, idx] = sort(Population.obj);
CA.dec = Population.dec(idx(1:N), :);
CA.obj = Population.obj(idx(1:N));
DA = Population;

while NFEs < MaxFEs
    % Remove duplicates from training data
    [unique_dec, unique_idx, ~] = unique(Training_data.dec, 'rows');
    unique_obj = Training_data.obj(unique_idx);
    
    % Add small noise to duplicate points if necessary
    if size(unique_dec, 1) < 2
        noise_scale = 1e-6 * (UB - LB);
        unique_dec = [unique_dec; unique_dec + noise_scale .* rand(1, dim)];
        unique_obj = [unique_obj; unique_obj(1)];
    end
    
    % Update Kriging model
    try
        dmodel = dacefit(unique_dec, unique_obj, 'regpoly0', 'corrgauss', THETA_S, 1e-5.*ones(1,dim), 100.*ones(1,dim));
        THETA_S = dmodel.theta;
    catch
        % If model fitting fails, continue with current model
        continue;
    end
    
    % Evolution process
    w = 1;
    while w <= wmax && NFEs < MaxFEs
        % Generate offspring using DE operators
        F = 0.5;  % Scale factor
        CR = 0.9; % Crossover rate
        
        % Generate offspring
        OffspringDec = zeros(N, dim);
        for i = 1:N
            % Random indices for DE
            r = randperm(N, 3);
            
            % DE/rand/1
            v = DA.dec(r(1),:) + F * (DA.dec(r(2),:) - DA.dec(r(3),:));
            
            % Binomial crossover
            cross_points = rand(1, dim) <= CR;
            if ~any(cross_points)
                cross_points(randi(dim)) = true;
            end
            OffspringDec(i,:) = v;
            OffspringDec(i,~cross_points) = DA.dec(i,~cross_points);
        end
        
        % Boundary control
        OffspringDec = max(min(OffspringDec, UB), LB);
        
        % Evaluate offspring using Kriging model
        PopDec = [DA.dec; CA.dec; OffspringDec];
        N2 = size(PopDec, 1);
        PopObj = zeros(N2, 1);
        MSE = zeros(N2, 1);
        
        for i = 1:N2
            try
                [PopObj(i), ~, MSE(i)] = predictor(PopDec(i,:), dmodel);
            catch
                PopObj(i) = inf;
                MSE(i) = inf;
            end
        end
        
        % Select best solutions based on predicted values
        [~, idx] = sort(PopObj);
        DA.dec = PopDec(idx(1:N), :);
        DA.obj = PopObj(idx(1:N));
        
        w = w + 1;
    end
    
    % Select solutions for re-evaluation based on MSE
    [~, idx] = sort(MSE, 'descend');
    Offspring = PopDec(idx(1:min(mu, size(PopDec,1))), :);
    
    % Remove duplicates from offspring
    Offspring = unique(Offspring, 'rows');
    
    % Real evaluation of selected solutions
    if ~isempty(Offspring)
        NewObj = fobj(Offspring);
        if size(NewObj, 2) > 1
            NewObj = NewObj(:);
        end
        NFEs = NFEs + size(Offspring, 1);
        
        % Update training data
        Training_data.dec = [Training_data.dec; Offspring];
        Training_data.obj = [Training_data.obj; NewObj];
        
        % Update convergence curve
        for i = (NFEs-size(Offspring,1)+1):NFEs
            cg_curve(1, i) = min([cg_curve(1, max(1,i-1)), min(NewObj)]);
        end
    end

    % Optional progress display
    if mod(NFEs, 100) == 0
        disp(['KTA2 -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
    end
end

% Fill remaining elements of cg_curve if NFEs < MaxFEs
if NFEs < MaxFEs
    cg_curve(1, NFEs+1:MaxFEs) = cg_curve(1, NFEs);
end


end