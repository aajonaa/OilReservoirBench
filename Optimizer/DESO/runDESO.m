function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_DESO(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);
    
    % Set population size from input
    N = popSize;

    % -------------- parameter initialization----------------------
    F = 0.5;  % scaling factor
    CR = 0.9; % crossover rate
    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);
    best_so_far = -inf;  % Track best solution found

    % -------------- generate initial samples-----------------------
    sam = repmat(lb, N, 1) + (repmat(ub, N, 1) - repmat(lb, N, 1)) .* lhsdesign(N, dim);
    for i = 1:size(sam, 1)
        fitness(i) = fobj(sam(i, :));
        count = count + 1;
        disp(['Current fobj count of DESO: ', num2str(count)]);
    end
    if size(fitness, 2) > 1
        fitness = fitness(:);  % Ensure column vector
    end

    for i = 1:N    
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, fitness(i));  % Changed to max for maximization
        convergence(NFEs) = best_so_far;
    end

    pop = sam;
    fit = fitness;

    % Main loop
    while NFEs < maxFEs
        % Sort population
        [fit_sorted, idx] = sort(fit, 'descend');  % Changed to descend for maximization
        pop_sorted = pop(idx,:);
        
        % Generate offspring using DESO operators
        for i = 1:N
            % Select parents
            r1 = randi([1,N]);
            while r1 == i
                r1 = randi([1,N]);
            end
            
            % Generate trial vector using DE mutation
            v = pop(i,:) + F*(pop_sorted(1,:) - pop(i,:)) + F*(pop(r1,:) - pop(i,:));
            
            % Boundary control
            v = max(min(v, ub), lb);
            
            % Evaluate new solution
            v_fit = fobj(v);
            count = count + 1;
            disp(['Current fobj count of DESO: ', num2str(count)]);
            NFEs = NFEs + 1;
            
            % Selection
            if v_fit > fit(i)  % Changed to > for maximization
                pop(i,:) = v;
                fit(i) = v_fit;
            end
            
            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, v_fit);  % Changed to max for maximization
            convergence(NFEs) = best_so_far;
            
            % Optional progress display
            if mod(NFEs, 100) == 0
                disp(['DESO -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
            end
            
            if NFEs >= maxFEs
                break;
            end
        end
    end

    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(fit);
    meanNPV = mean(fit);
    runTime = toc;

    % Print final results
    fprintf('DESO run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end