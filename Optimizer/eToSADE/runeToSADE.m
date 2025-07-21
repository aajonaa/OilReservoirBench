function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_eToSADE(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);
    
    % Set population size from input
    N = popSize;

    % -------------- parameter initialization----------------------
    LP = 50;  % Learning period
    memory_size = 5;
    F_memory = 0.5 * ones(memory_size, 1);
    CR_memory = 0.5 * ones(memory_size, 1);
    k = 1;  % Memory index
    p_best = 0.05; % Top p% individuals
    archive = [];   % External archive
    archive_size = N;

    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);

    % -------------- generate initial samples-----------------------
    sam = repmat(lb, N, 1) + (repmat(ub, N, 1) - repmat(lb, N, 1)) .* lhsdesign(N, dim);
    for i = 1:size(sam, 1)
        fitness(i) = fobj(sam(i, :));
        count = count + 1;
        disp(['Current fobj count of eToSADE: ', num2str(count)]);
    end
    if size(fitness, 2) > 1
        fitness = fitness(:);  % Ensure column vector
    end

    best_so_far = -inf;  % Track best solution found
    for i = 1:N    
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, fitness(i));
        convergence(NFEs) = best_so_far;
    end
    
    hx = sam; 
    hisFit = fitness;

    while NFEs < maxFEs 
        % -------------- Sort population ----------------------
        [~, sort_index] = sort(hisFit);
        ghx = hx(sort_index,:);
        ghf = hisFit(sort_index);
        
        % -------------- Generate offspring ----------------------
        offspring = [];
        
        % eToSADE mutation and crossover
        for i = 1:N
            % Select F and CR values
            if rand < 0.5
                F = F_memory(randi(memory_size));
                CR = CR_memory(randi(memory_size));
            else
                F = randn * 0.3 + 0.5;
                CR = rand;
            end
            
            % Select p_best individual
            p_best_idx = randi(max(1, round(p_best * N)));
            
            % Select parents
            r1 = randi(N);
            while r1 == i || r1 == p_best_idx
                r1 = randi(N);
            end
            
            % Select from extended population (including archive)
            extended_pop = [hx; archive];
            r2 = randi(size(extended_pop, 1));
            while r2 == i || r2 == r1 || r2 == p_best_idx
                r2 = randi(size(extended_pop, 1));
            end
            
            % Generate trial vector using current-to-pbest/1/bin
            v = hx(i,:) + F * (ghx(p_best_idx,:) - hx(i,:)) + F * (hx(r1,:) - extended_pop(r2,:));
            
            % Crossover
            j_rand = randi(dim);
            u = hx(i,:);
            for j = 1:dim
                if (rand <= CR || j == j_rand)
                    u(j) = v(j);
                end
            end
            
            % Bound constraint handling
            u = max(min(u, ub), lb);
            
            offspring = [offspring; u];
        end
        
        % -------------- Evaluate offspring ----------------------
        for i = 1:size(offspring,1)
            candidate_position = offspring(i,:);
            
            % Check if candidate already exists
            [~,ih,~] = intersect(hx, candidate_position, 'rows');
            if ~isempty(ih)
                continue;
            end
            
            % Evaluate candidate
            candidate_fit = fobj(candidate_position);
            count = count + 1;
            disp(['Current fobj count of eToSADE: ', num2str(count)]);
            NFEs = NFEs + 1;
            if NFEs > maxFEs
                break
            end
            
            % Selection and archive update
            if candidate_fit >= hisFit(i)  % Changed to >= for maximization
                % Update archive
                if size(archive, 1) >= archive_size
                    archive(randi(archive_size),:) = hx(i,:);
                else
                    archive = [archive; hx(i,:)];
                end
                
                % Update population
                hx(i,:) = candidate_position;
                hisFit(i) = candidate_fit;
                
                % Update memory
                if mod(NFEs, LP) == 0
                    F_memory(k) = F;
                    CR_memory(k) = CR;
                    k = mod(k, memory_size) + 1;
                end
            end
            
            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, candidate_fit);
            convergence(NFEs) = best_so_far;
            
            % Optional progress display
            if mod(NFEs, 100) == 0
                disp(['eToSADE -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
            end
        end
    end

    % Fill remaining convergence curve values if needed
    if NFEs < maxFEs
        convergence(NFEs+1:maxFEs) = best_so_far;
    end

    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(hisFit);
    meanNPV = mean(hisFit);
    runTime = toc;

    % Print final results
    fprintf('eToSADE run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end