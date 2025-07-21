function [cg_curve] = ESA(N, MaxFEs, LB, UB, dim, fobj)

% Initialize bounds
LB = repmat(LB, 1, dim);
UB = repmat(UB, 1, dim);

% Parameter initialization
alpha = 0.95;      % Cooling rate
T0 = 1;           % Initial temperature
NFEs = 0;
cg_curve = zeros(1,MaxFEs);
CE = zeros(MaxFEs,2);

% Generate initial population using Latin Hypercube Sampling
pop = repmat(LB,N,1)+(repmat(UB,N,1)-repmat(LB,N,1)).*lhsdesign(N,dim);
fitness = fobj(pop);
if size(fitness,2) > 1
    fitness = fitness(:);  % Ensure column vector
end

% Evaluate initial population
for i=1:N    
    NFEs = NFEs + 1;
    CE(NFEs,:) = [NFEs,fitness(i)];
    cg_curve(1,NFEs) = min(CE(1:NFEs,2));
end

% Main optimization loop
while NFEs < MaxFEs
    % Sort population
    [fitness, sort_idx] = sort(fitness);
    pop = pop(sort_idx,:);
    
    % Get current best solution
    best_solution = pop(1,:);
    best_fitness = fitness(1);
    
    % Current temperature
    T = T0 * alpha^(NFEs/MaxFEs);
    
    % Generate new solution
    for i = 1:N
        % Create neighbor solution
        neighbor = pop(i,:) + T * randn(1,dim);
        
        % Bound constraints
        neighbor = max(min(neighbor, UB), LB);
        
        % Evaluate new solution
        neighbor_fitness = fobj(neighbor);
        NFEs = NFEs + 1;
        
        % Update convergence curve
        CE(NFEs,:) = [NFEs, neighbor_fitness];
        cg_curve(1,NFEs) = min([CE(1:NFEs,2); best_fitness]);  % Include current best
        
        % Acceptance probability
        delta = neighbor_fitness - fitness(i);
        if delta < 0 || rand < exp(-delta/T)
            pop(i,:) = neighbor;
            fitness(i) = neighbor_fitness;
        end
        
        if NFEs >= MaxFEs
            break
        end
    end
    
    if NFEs >= MaxFEs
        break
    end
end

% Fill remaining positions in cg_curve with the best found value
if NFEs < MaxFEs
    cg_curve(NFEs+1:end) = cg_curve(NFEs);
end
% Optional progress display
if mod(NFEs, 100) == 0
    disp(['ESA -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
end
end