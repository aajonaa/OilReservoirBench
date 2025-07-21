function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_TSABFEA(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);
    
    % Set population size from input
    N = popSize;

    % Initialize parameters
    bu = ub;
    bd = lb;
    nc = dim;
    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);  % Initialize with zeros
    TrainSize = N;
    best_so_far = -inf;  % Track best solution found

    % Initialize training data
    POP = initialize_popLHS(N, dim, bu, bd);
    for i = 1:size(POP, 1)
        obj(i) = fobj(POP(i, :));
        count = count + 1;
        disp(['Current fobj count: ', num2str(count)]);
    end
    if size(obj,2) > 1
        obj = obj(:);
    end
    % Update NFEs and curve for each initial evaluation
    for i = 1:size(POP,1)
        if NFEs >= maxFEs
            break;
        end
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, obj(i));
        convergence(NFEs) = best_so_far;
    end
    POP = [POP, obj];
    Train = POP;

    % Initialize main population
    if NFEs < maxFEs
        POP = initialize_pop(N, dim, bu, bd);
        for i = 1:size(POP, 1)
            obj(i) = fobj(POP(i, :));
            count = count + 1;
            disp(['Current fobj count of TSA-BFEA: ', num2str(count)]);
        end
        if size(obj,2) > 1
            obj = obj(:);
        end
        % Update NFEs and curve for each evaluation
        for i = 1:size(POP,1)
            if NFEs >= maxFEs
                break;
            end
            NFEs = NFEs + 1;
            best_so_far = max(best_so_far, obj(i));
            convergence(NFEs) = best_so_far;
        end
        POP = [POP, obj];
    end

    % Algorithm parameters
    pc = 1;
    pm = 1/dim;
    g = 0;
    gmax = 20000;
    nls = 2;

    % Main loop
    while NFEs < maxFEs && g < gmax
        % Generate and evaluate offspring
        NPOP = SBX(POP(:,1:dim), bu, bd, pc, N);
        NPOP = mutation(NPOP, bu, bd, pm);
        for i = 1:size(NPOP, 1)
            obj(i) = fobj(NPOP(i, :));
        end
        count = count + 1;
        disp(['Current fobj count of TSA-BFEA: ', num2str(count)]);
        % if size(obj,2) > 1
        %     obj = obj(:);
        % end
        
        % Update NFEs and convergence curve
        for i = 1:size(NPOP,1)
            if NFEs >= maxFEs
                break;
            end
            NFEs = NFEs + 1;
            best_so_far = max(best_so_far, obj(i));
            convergence(NFEs) = best_so_far;
        end
        
        if NFEs >= maxFEs
            break;
        end
        
        NPOP = [NPOP, obj];
        POP = [POP(:,1:dim+1); NPOP];

        % RBF and ensemble predictions
        [W2,B2,Centers,Spreads] = RBF_TSABFEA(Train(:,1:dim), Train(:,dim+1), nc);
        pred_obj = RBF_predictor(W2, B2, Centers, Spreads, POP(:,1:dim));
        POP = [POP, pred_obj];

        IN = NearestNeighbor(POP, Train, dim);
        nn_pred = RBF_predictor(W2, B2, Centers, Spreads, Train(IN,1:dim));
        
        A = [Train(IN,dim+1), nn_pred];
        w = A\Train(IN,dim+1);
        ensemble_pred = [POP(:,dim+1), pred_obj]*w;
        POP = [POP, ensemble_pred];

        [~, sort_idx] = sort(POP(:,dim+2), 'descend');
        POP = POP(sort_idx(1:N),:);
        
        if size(Train,1) > TrainSize
            Train = Train(size(Train,1)-TrainSize+1:end,:);
        end

        % Select and evaluate promising solutions
        EX = POP;
        dis = MinDis(EX(:,1:dim), Train(:,1:dim), dim);
        EX = EX(dis~=0,:);
        if isempty(EX)
            dis = MinDis(POP(:,1:dim), Train(:,1:dim), dim);
            I = find(dis~=0);
            if ~isempty(I)
                [~,Ii] = sort(POP(I,dim+1), 'descend');
                EX = POP(I(Ii(1:min(nls,length(I)))),:);
            end
        elseif size(EX,1) > nls
            [~,Ii] = sort(EX(:,dim+1), 'descend');
            EX = EX(Ii(1:nls),:);
        end

        if ~isempty(EX) && NFEs < maxFEs
            obj = fobj(EX(:,1:dim));
            count = count + 1;
            disp(['Current fobj count of TSA-BFEA: ', num2str(count)]);
            if size(obj,2) > 1
                obj = obj(:);
            end
            
            % Update NFEs and convergence curve
            for i = 1:size(EX,1)
                if NFEs >= maxFEs
                    break;
                end
                NFEs = NFEs + 1;
                best_so_far = max(best_so_far, obj(i));
                convergence(NFEs) = best_so_far;
            end
            
            if NFEs < maxFEs
                Train = [Train; [EX(:,1:dim), obj]];
            end
        end
        
        g = g + 1;

        % Optional progress display
        if mod(NFEs, 100) == 0
            disp(['TSA-BFEA -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
        end
    end

    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(Train(:,dim+1));
    meanNPV = mean(Train(:,dim+1));
    runTime = toc;

    % Print final results
    fprintf('TSA-BFEA run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end
