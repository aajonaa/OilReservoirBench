function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_BEXEA(popSize, maxFEs, lb, ub, fobj)
    % `BEX-SAEC: Bandit-Driven Adaptive Search in Surrogate-Assisted Evolutionary Algorithm with Explainable Uncertainty Criteria`
    % BEXEA - v2 Without DEbest and DErand 2025-3-2
    % Change the runBEXEA problem to the maximum optimization problem. 3-3

    % Start timer
    tic;
    
    % Determine problem dimensionality (nDim = number of decision variables)
    dim = numel(lb);
    
    % Parameters
    T = 20;        % Adaptive offspring size
    arms = 2;                         % Number of strategies (added QPSO)
    epsilon = 0.1;                    % Epsilon for epsilon-greedy
    window_size = 20;                 % Window size

    % Training sample parameters
    if dim < 100
        N = popSize;                          % < 100 dimension
    else
        N = 150;                          % >= 100 dimension
    end

    % Data archive
    Data = [];                        % Archive for surrogate model

    % Rename and initialize tracking variables to match DE_best style
    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);  % Renamed from cg_curve to convergence
    Q = zeros(1, arms);
    recent_rewards = zeros(window_size, arms);
    window_idx = 1;
    best_so_far = -1 * inf;
    stagnation_counter = 0;

    % Initialize population using LHS
    X = lhsdesign(N, dim) .* (ones(N, 1) * (ub - lb)) + ones(N, 1) * lb;
    fitness = -inf * ones(N, 1);

    % Initial evaluations
    for i = 1:N
        fitness(i) = fobj(X(i, :));
        count = count + 1;
        disp(['Current fobj count of BEXEA: ', num2str(count)]);
        Data = [Data; X(i,:), fitness(i)];
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, fitness(i));
        convergence(NFEs) = best_so_far;
    end

    % Initialize best_sol with the best solution from the initial population
    [~, index] = max(fitness);
    best_sol = X(index, :);  % This line is added to initialize best_sol

    % Initialize the reward decay factor
    decay_factor = 0.3;  % You can change this value based on your preference
    reward_history = zeros(arms, 1);  % Keep track of rewards for each strategy

    % Main loop
    while NFEs < maxFEs
        % Adaptive search behavior
        srgtOPT = srgtsRBFSetOptions(X, fitness);
        srgtSRGTRBF = srgtsRBFFit(srgtOPT);

        % Strategy selection with epsilon-greedy method
        if stagnation_counter > 20
            strategy = randi(arms);
            epsilon = min(0.3, epsilon * 1.1);
        else
            if rand < epsilon
                strategy = randi(arms);
            else
                [~, strategy] = max(Q);
            end
        end

        % Generate offspring based on strategy
        [~, best_idx] = max(fitness);
        Xbest = X(best_idx, :);
        lbest = X;
        g_best = Xbest;

        switch strategy
            case 1  % DE/best/1
                % offspring = DErand1EU(X, F, CR, UB, LB, T);
                offspring = EDAEU(X, lb, ub, T); 
            case 2  % EDA
                offspring = QPSO(X, ub, lb, g_best, lbest, NFEs, maxFEs); 
        end

        % Enhanced surrogate-based screening
        offspring_pred = rbf_predict(srgtSRGTRBF.RBF_Model, srgtSRGTRBF.P, offspring);
        eu = EUcriteria(X, fitness, offspring);
        combined_score = offspring_pred + 0.5 * (max(eu) - eu);
        [~, idx] = sort(combined_score, 'descend');

        % Select and evaluate promising candidates
        num_candidates = min(3, size(offspring, 1));
        success = false;

        for k = 1:num_candidates
            if NFEs >= maxFEs
                break;
            end

            candidate = offspring(idx(k), :);
            candidate_fitness = fobj(candidate);
            count = count + 1;
            disp(['Current fobj count of BEXEA: ', num2str(count)]);
            NFEs = NFEs + 1;

            % Update archive
            Data = [Data; candidate, candidate_fitness];

            % Calculate reward with decay factor and reliability consideration
            prev_best = max(fitness);
            improvement = max(0, prev_best - candidate_fitness);
            if strategy == 2
                reward = improvement / (prev_best + eps) + 0.1 * eu(idx(k));
            else
                diversity = min(pdist2(candidate, X));
                reward = improvement / (prev_best + eps) + 0.1 * diversity / dim;
            end

            % Apply decay to the reward
            reward_history(strategy) = (1 - decay_factor) * reward_history(strategy) + decay_factor * reward;
            Q(strategy) = reward_history(strategy);  % Update action-value estimate

            % Update population
            if candidate_fitness < min(fitness)
                [~, worst_idx] = min(fitness);
                X(worst_idx, :) = candidate;
                fitness(worst_idx) = candidate_fitness;
                success = true;
                stagnation_counter = 0;
            end

            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, candidate_fitness);
            convergence(NFEs) = best_so_far;

            if success && improvement > 0
                break;  % Exit if improvement found
            end
        end

        % Update stagnation counter
        if ~success
            stagnation_counter = stagnation_counter + 1;
        end

        % Optional progress display
        if mod(NFEs, 100) == 0
            disp(['BEXEA v2 -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
        end

        [~, index] = max(fitness);
        best_sol = X(index, :);

    end

    % Fill remaining convergence curve values
    if NFEs < maxFEs
        convergence(NFEs+1:maxFEs) = best_so_far;
    end
    
    % Compute final statistics to match DE_best output
    bestNPV = best_so_far;
    worstNPV = min(fitness);
    meanNPV = mean(fitness);
    runTime = toc;
    
    % Add final print statement to match DE_best
    fprintf('BEXEA run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end
