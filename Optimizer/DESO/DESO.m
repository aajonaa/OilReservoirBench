function [cg_curve] = DESO(N, MaxFEs, LB, UB, dim, fobj)

LB = repmat(LB, 1, dim);
UB = repmat(UB, 1, dim);

% -------------- parameter initialization----------------------
F = 0.5;  % scaling factor
CR = 0.9; % crossover rate
NFEs = 0;
cg_curve = zeros(1,MaxFEs);

% -------------- generate initial samples-----------------------
sam = repmat(LB,N,1) + (repmat(UB,N,1)-repmat(LB,N,1)).*lhsdesign(N,dim);
fitness = fobj(sam);
if size(fitness,2) > 1
    fitness = fitness(:);  % Ensure column vector
end

for i=1:N    
    NFEs = NFEs + 1;
    CE(NFEs,:) = [NFEs,fitness(i)];
    cg_curve(1,NFEs) = min(CE(1:NFEs,2));
end

pop = sam;
fit = fitness;

% Main loop
while NFEs < MaxFEs
    % Sort population
    [fit_sorted, idx] = sort(fit);
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
        v = max(min(v,UB),LB);
        
        % Evaluate new solution
        v_fit = fobj(v);
        NFEs = NFEs + 1;
        
        % Selection
        if v_fit < fit(i)
            pop(i,:) = v;
            fit(i) = v_fit;
        end
        
        % Update convergence curve
        CE(NFEs,:) = [NFEs,v_fit];
        cg_curve(1,NFEs) = min(CE(1:NFEs,2));       
        % Optional progress display
        if mod(NFEs, 100) == 0
            disp(['DESO -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
        end
        
        if NFEs >= MaxFEs
            break;
        end
    end
end
end