function [cg_curve] = eToSADE(N, MaxFEs, LB, UB, dim, fobj)

LB = repmat(LB, 1, dim);
UB = repmat(UB, 1, dim);

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
cg_curve = zeros(1,MaxFEs);

% -------------- generate initial samples-----------------------
sam = repmat(LB,N,1) + (repmat(UB,N,1)-repmat(LB,N,1)).*lhsdesign(N,dim);
fitness = fobj(sam);
if size(fitness,2) > 1
    fitness = fitness(:);  % Ensure column vector
end

for i=1:N    
    NFEs = NFEs+1;
    CE(NFEs,:) = [NFEs,fitness(i)];
    cg_curve(1,NFEs) = min(CE(1:NFEs,2));
end
hx = sam; 
hisFit = fitness;

while NFEs < MaxFEs 
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
        u = max(min(u, UB), LB);
        
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
        NFEs = NFEs + 1;
        if NFEs > MaxFEs
            break
        end
        
        % Selection and archive update
        if candidate_fit <= hisFit(i)
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
        
        % Update convergence curve
        CE(NFEs,:) = [NFEs, candidate_fit];
        cg_curve(1,NFEs) = min(CE(1:NFEs,2));
        % Optional progress display
        if mod(NFEs, 100) == 0
            disp(['eToSADE -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
        end
    end
end
end