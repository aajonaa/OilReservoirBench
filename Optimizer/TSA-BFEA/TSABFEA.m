function [cg_curve] = TSABFEA(N, MaxFEs, LB, UB, dim, fobj)

% Initialize parameters
bu = repmat(UB, 1, dim);
bd = repmat(LB, 1, dim);
n = N;
nc = dim;
NFEs = 0;
cg_curve = inf(1, MaxFEs);  % Initialize with inf
TrainSize = n;

% Initialize training data
POP = initialize_popLHS(n, dim, bu, bd);
obj = fobj(POP);
if size(obj,2) > 1
    obj = obj(:);
end
% Update NFEs and curve for each initial evaluation
for i = 1:size(POP,1)
    NFEs = NFEs + 1;
    if i == 1
        best_so_far = obj(1);
    else
        best_so_far = min(best_so_far, obj(i));
    end
    cg_curve(NFEs) = best_so_far;
end
POP = [POP, obj];
Train = POP;

% Initialize main population
POP = initialize_pop(n, dim, bu, bd);
obj = fobj(POP);
if size(obj,2) > 1
    obj = obj(:);
end
% Update NFEs and curve for each evaluation
for i = 1:size(POP,1)
    NFEs = NFEs + 1;
    best_so_far = min(best_so_far, obj(i));
    cg_curve(NFEs) = best_so_far;
end
POP = [POP, obj];

% Algorithm parameters
pc = 1;
pm = 1/dim;
g = 0;
gmax = 20000;
nls = 2;

% Main loop
while NFEs < MaxFEs && g < gmax
    % Generate and evaluate offspring
    NPOP = SBX(POP(:,1:dim), bu, bd, pc, n);
    NPOP = mutation(NPOP, bu, bd, pm);
    obj = fobj(NPOP);
    if size(obj,2) > 1
        obj = obj(:);
    end
    
    % Update NFEs and convergence curve
    new_NFEs = NFEs + size(NPOP,1);
    if new_NFEs > MaxFEs
        valid_evals = MaxFEs - NFEs;
        NFEs = MaxFEs;
    else
        valid_evals = size(NPOP,1);
        NFEs = new_NFEs;
    end
    
    best_so_far = min([best_so_far; obj(1:valid_evals)]);
    cg_curve(NFEs-valid_evals+1:NFEs) = best_so_far;
    
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

    [~, sort_idx] = sort(POP(:,dim+2));
    POP = POP(sort_idx(1:n),:);
    
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
            [~,Ii] = sort(POP(I,dim+1));
            EX = POP(I(Ii(1:min(nls,length(I)))),:);
        end
    elseif size(EX,1) > nls
        [~,Ii] = sort(EX(:,dim+1));
        EX = EX(Ii(1:nls),:);
    end

    if ~isempty(EX) && NFEs < MaxFEs
        obj = fobj(EX(:,1:dim));
        if size(obj,2) > 1
            obj = obj(:);
        end
        
        % Update NFEs and convergence curve
        new_NFEs = NFEs + size(EX,1);
        if new_NFEs > MaxFEs
            valid_evals = MaxFEs - NFEs;
            NFEs = MaxFEs;
        else
            valid_evals = size(EX,1);
            NFEs = new_NFEs;
        end
        
        best_so_far = min([best_so_far; obj(1:valid_evals)]);
        cg_curve(NFEs-valid_evals+1:NFEs) = best_so_far;
        
        Train = [Train; [EX(:,1:dim), obj]];
    end
    
    g = g + 1;
end

% Fill any remaining positions with the best value found
if NFEs < MaxFEs
    cg_curve(NFEs+1:MaxFEs) = best_so_far;
end
% Optional progress display
if mod(NFEs, 100) == 0
    disp(['TSA-BFEA -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
end

end
