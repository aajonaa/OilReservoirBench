function [bestNPV, worstNPV, meanNPV, runTime, convergence] = runSHPSO(popSize, maxFEs, lb, ub, fobj)
    % Simple Differential Evolution (DE) Algorithm
    % Replaces SHPSO with clean DE implementation

    % Start timer
    tic;

    % Determine problem dimensionality
    dim = numel(lb);

    % DE parameters
    F = 0.8;        % Mutation factor (scaling factor) - increased for more diversity
    CR = 0.9;       % Crossover rate

    % Initialize tracking variables
    NFEs = 0;
    convergence = zeros(1, maxFEs);

    % Initialize population randomly within bounds
    population = repmat(lb, popSize, 1) + repmat(ub - lb, popSize, 1) .* rand(popSize, dim);
    fitness = zeros(popSize, 1);

    % Evaluate initial population
    for i = 1:popSize
        fitness(i) = fobj(population(i, :));
        NFEs = NFEs + 1;

        % Update convergence curve
        if i == 1
            best_so_far = fitness(i);
        else
            best_so_far = max(best_so_far, fitness(i));
        end
        convergence(NFEs) = best_so_far;

        if NFEs >= maxFEs
            break;
        end
    end


    % Main DE loop
    generation = 1;
    while NFEs < maxFEs
        % Create temporary arrays for new generation (to avoid mid-generation updates)
        new_population = population;  % Start with current population
        new_fitness = fitness;        % Start with current fitness

        for i = 1:popSize
            if NFEs >= maxFEs
                break;
            end

            % DE/rand/1 mutation strategy
            % Select three random individuals (different from current)
            candidates = setdiff(1:popSize, i);
            r = candidates(randperm(length(candidates), 3));
            r1 = r(1); r2 = r(2); r3 = r(3);

            % Mutation: V = X_r1 + F * (X_r2 - X_r3) (use ORIGINAL population)
            mutant = population(r1, :) + F * (population(r2, :) - population(r3, :));

            % Boundary handling: reflect back into bounds
            mutant = max(mutant, lb);
            mutant = min(mutant, ub);

            % Crossover: binomial crossover
            trial = population(i, :);  % Use original population
            j_rand = randi(dim);  % Ensure at least one dimension is from mutant

            for j = 1:dim
                if rand <= CR || j == j_rand
                    trial(j) = mutant(j);
                end
            end

            % Debug: Check if trial is identical to existing solutions
            trial_rounded = round(trial, 6);  % Round to avoid floating point issues

            % Evaluate trial vector
            trial_fitness = fobj(trial);
            NFEs = NFEs + 1;

            % Selection: keep better solution (UPDATE TEMPORARY ARRAYS)
            if trial_fitness > fitness(i)  % Maximization
                new_population(i, :) = trial;        % Update temporary population
                new_fitness(i) = trial_fitness;      % Update temporary fitness
            else
                new_population(i, :) = population(i, :);  % Keep current solution
                new_fitness(i) = fitness(i);             % Keep current fitness
            end

            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, new_fitness(i));
            convergence(NFEs) = best_so_far;
        end

        % Update population for next generation (AFTER all evaluations)
        population = new_population;
        fitness = new_fitness;

        generation = generation + 1;
    end


    % Fill remaining convergence curve values if needed
    if NFEs < maxFEs
        convergence(NFEs+1:maxFEs) = best_so_far;
    end

    % Compute final statistics
    bestNPV = max(fitness);
    worstNPV = min(fitness);
    meanNPV = mean(fitness);
    runTime = toc;

    % Print final results
    fprintf('DE run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end