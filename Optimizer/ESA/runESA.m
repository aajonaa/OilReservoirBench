function [bestNPV, worstNPV, meanNPV, runTime, convergence] = runESA(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);
    
    % Set population size from input
    N = popSize;

    % Parameter initialization
    alpha = 0.95;      % Cooling rate
    T0 = 1;           % Initial temperature
    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);

    % Generate initial population using Latin Hypercube Sampling
    pop = repmat(lb, N, 1) + (repmat(ub, N, 1) - repmat(lb, N, 1)) .* lhsdesign(N, dim);
    for i = 1:size(pop, 1)
        fitness(i) = fobj(pop(i, :));
        count = count + 1;
        disp(['Current fobj count of ESA: ', num2str(count)]);
    end
    if size(fitness, 2) > 1
        fitness = fitness(:);  % Ensure column vector
    end

    % Evaluate initial population
    best_so_far = -inf;  % Initialize best solution found
    for i = 1:N    
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, fitness(i));
        convergence(NFEs) = best_so_far;
    end

    % Main optimization loop
    while NFEs < maxFEs
        % Sort population
        [fitness, sort_idx] = sort(fitness);
        pop = pop(sort_idx,:);
        
        % Get current best solution
        best_solution = pop(1,:);
        best_fitness = fitness(1);
        
        % Current temperature
        T = T0 * alpha^(NFEs/maxFEs);
        
        % Generate new solution
        for i = 1:N
            % Create neighbor solution
            neighbor = pop(i,:) + T * randn(1, dim);
            
            % Bound constraints
            neighbor = max(min(neighbor, ub), lb);
            
            % Evaluate new solution
            neighbor_fitness = fobj(neighbor);
            count = count + 1;
            disp(['Current fobj count of ESA: ', num2str(count)]);
            NFEs = NFEs + 1;
            
            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, neighbor_fitness);
            convergence(NFEs) = best_so_far;
            
            % Acceptance probability
            delta = neighbor_fitness - fitness(i);
            if delta < 0 || rand < exp(-delta/T)
                pop(i,:) = neighbor;
                fitness(i) = neighbor_fitness;
            end
            
            % Optional progress display
            if mod(NFEs, 100) == 0
                disp(['ESA -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
            end
            
            if NFEs >= maxFEs
                break;
            end
        end
        
        if NFEs >= maxFEs
            break;
        end
    end

    % Fill remaining positions in convergence with the best found value
    if NFEs < maxFEs
        convergence(NFEs+1:end) = best_so_far;
    end

    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(fitness);
    meanNPV = mean(fitness);
    runTime = toc;

    % Print final results
    fprintf('ESA run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end