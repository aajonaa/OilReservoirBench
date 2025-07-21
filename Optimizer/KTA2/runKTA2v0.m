function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_KTA2(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);
    
    % Set population size from input
    N = popSize;

    % Algorithm parameters
    mu = 5;          % Number of re-evaluated solutions at each generation
    wmax = 3;        % Number of generations before updating model (kept same as original KTA2v1)
    model_update_freq = 10;  % Sparse model updates
    THETA_S = 5.*ones(1, dim);
    training_size = min(25, N); % Limited training size

    % Initialize tracking variables
    NFEs = 0;
    convergence = zeros(1, maxFEs);
    best_so_far = -inf;  % Changed to -inf for maximization

    % Generate initial population using Latin Hypercube Sampling
    P = lhsdesign(N, dim);
    Population.dec = repmat(lb, N, 1) + (repmat(ub - lb, N, 1)).*P;
    Population.obj = zeros(N, 1);
    
    % Evaluate initial population
    for i = 1:N
        Population.obj(i) = fobj(Population.dec(i, :));
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, Population.obj(i));
        convergence(1, NFEs) = best_so_far;
    end

    % Initialize archives and training data
    [~, idx] = sort(Population.obj, 'descend');  % Changed to descend for maximization
    Training_data.dec = Population.dec(idx(1:training_size), :);
    Training_data.obj = Population.obj(idx(1:training_size));
    CA = Population;
    DA = Population;

    % Main loop
    generation = 0;
    while NFEs < maxFEs
        generation = generation + 1;
        
        % Update Kriging model
        if generation == 1 || mod(generation, model_update_freq) == 0
            try
                % Remove duplicates from training data
                [unique_dec, unique_idx, ~] = unique(Training_data.dec, 'rows');
                unique_obj = Training_data.obj(unique_idx);
                
                % Add small noise to duplicate points if necessary
                if size(unique_dec, 1) < 2
                    noise_scale = 1e-6 * (ub - lb);
                    unique_dec = [unique_dec; unique_dec + noise_scale .* rand(1, dim)];
                    unique_obj = [unique_obj; unique_obj(1)];
                end
                
                % Select best points for training
                [~, idx] = sort(unique_obj, 'descend');  % Changed to descend for maximization
                selected_idx = idx(1:min(training_size, length(idx)));
                train_x = unique_dec(selected_idx, :);
                train_y = unique_obj(selected_idx);
                
                % Fit Kriging model
                dmodel = dacefit(train_x, train_y, 'regpoly0', 'corrgauss', THETA_S, 1e-5.*ones(1,dim), 100.*ones(1,dim));
                THETA_S = dmodel.theta;
            catch
                continue;
            end
        end
        
        % Evolution process
        w = 1;
        while w <= wmax && NFEs < maxFEs
            % Generate offspring using DE
            F = 0.5;
            CR = 0.9;
            
            % Generate offspring
            OffspringDec = zeros(N, dim);
            for i = 1:N
                % DE/rand/1
                r = randperm(N, 3);
                v = DA.dec(r(1),:) + F * (DA.dec(r(2),:) - DA.dec(r(3),:));
                
                % Crossover
                mask = rand(1, dim) <= CR;
                if ~any(mask)
                    mask(randi(dim)) = true;
                end
                OffspringDec(i,:) = v .* mask + DA.dec(i,:) .* ~mask;
            end
            
            % Boundary control
            OffspringDec = max(min(OffspringDec, ub), lb);
            
            % Predict using Kriging
            try
                [PopObj, MSE] = predictor(OffspringDec, dmodel);
                
                % Ensure correct dimensions
                PopObj = reshape(PopObj, N, 1);
                MSE = reshape(MSE, N, 1);
            catch
                PopObj = -inf(N, 1);  % Changed to -inf for maximization
                MSE = ones(N, 1);
            end
            
            % Select promising solutions based on predicted values and uncertainty
            [~, idx] = sort(MSE, 'descend');  % Select based on highest uncertainty
            candidates = OffspringDec(idx(1:min(mu, N)), :);
            
            % Remove duplicates from candidates
            candidates = unique(candidates, 'rows');
            
            % Evaluate selected solutions
            if ~isempty(candidates)
                new_obj = fobj(candidates);
                if size(new_obj, 2) > 1
                    new_obj = new_obj(:); % Ensure column vector format
                end
                
                % Update tracking variables
                for i = 1:size(candidates, 1)
                    NFEs = NFEs + 1;
                    best_so_far = max(best_so_far, new_obj(i));
                    if NFEs <= maxFEs
                        convergence(1, NFEs) = best_so_far;
                    end
                end
                
                % Update population
                for i = 1:size(candidates, 1)
                    if new_obj(i) > min(DA.obj)  % Changed to > for maximization
                        [~, worst] = min(DA.obj); % Changed to min for maximization
                        DA.dec(worst,:) = candidates(i,:);
                        DA.obj(worst) = new_obj(i);
                    end
                end
                
                % Update training data
                Training_data.dec = [Training_data.dec; candidates];
                Training_data.obj = [Training_data.obj; new_obj];
                
                % Limit training data size if needed
                if size(Training_data.dec, 1) > 100
                    [~, idx] = sort(Training_data.obj, 'descend');  % Changed to descend for maximization
                    Training_data.dec = Training_data.dec(idx(1:100), :);
                    Training_data.obj = Training_data.obj(idx(1:100));
                end
            end
            
            w = w + 1;
        end
        
        % Progress display
        if mod(NFEs, 100) == 0
            disp(['KTA2 v1 -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
        end
    end

    % Fill remaining elements
    if NFEs < maxFEs
        convergence(NFEs+1:maxFEs) = best_so_far;
    end
    
    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(Training_data.obj);
    meanNPV = mean(Training_data.obj);
    runTime = toc;

    % Print final results
    fprintf('KTA2 run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end