function [cg_curve] = MS_MTO2(N, MaxFEs, LB, UB, dim, fobj)

% Create Tasks structure with 3 tasks (GMFEA needs length(Tasks)-1 >= 2)
Tasks = struct();
for i = 1:3  % Create 3 tasks, GMFEA will use tasks 1 and 2
    Tasks(i).dims = dim;
    Tasks(i).Lb = repmat(LB, 1, dim);
    Tasks(i).Ub = repmat(UB, 1, dim);
    Tasks(i).fnc = fobj;
    % Additional required fields
    Tasks(i).name = ['Task_' num2str(i)];
    Tasks(i).n_var = dim;
    Tasks(i).xl = Tasks(i).Lb;
    Tasks(i).xu = Tasks(i).Ub;
end

% Algorithm parameters
pop = N;
gen = 1;
rmp = 0.3;
achieve_num = N/2;

y_y = dim + 1;
minrange = Tasks(1).Lb;
maxrange = Tasks(1).Ub;
y = maxrange - minrange;

% Initialize convergence curve
cg_curve = zeros(1, MaxFEs);

% Initialize variables
lhs = [];
archive = [];
NFEs = 0;
generation = 0;
mu = 1;
mum = 1;
distance_m = ((MaxFEs-achieve_num)/2)/10;
toall_distance = distance_m;

% Initial archive
lhs = lhsdesign(achieve_num, dim);
for i = 1:achieve_num
    lhs(i,1:dim) = y.*lhs(i,1:dim) + minrange;
    lhs(i,dim+1) = fobj(lhs(i,1:dim));
    NFEs = NFEs + 1;
    cg_curve(1,NFEs) = min(lhs(1:i,dim+1));
end
archive = lhs;
generation = generation + 1;

[~,yy] = sort(archive(:,dim+1));
archive = archive(yy,:);
best_one = archive(1,:);

while NFEs < MaxFEs
    % Initial or update RBF
    length_achieve = size(archive,1);
    flag1 = 'cubic';
    
    % % Global model
    % [lambda1, gamma1] = RBF(archive(:,1:dim), archive(:,dim+1), flag1);
    % Tasks(1).fnc = @(x) RBF_eval(x, archive(:,1:dim), lambda1, gamma1, flag1);
    % 
    % % Local model
    % [lambda1, gamma1] = RBF(archive(1:achieve_num,1:dim), archive(1:achieve_num,y_y), flag1);
    % Tasks(2).fnc = @(x) RBF_eval(x, archive(1:achieve_num,1:dim), lambda1, gamma1, flag1);
    % 
    % % Third task remains with original objective function
    % Tasks(3).fnc = fobj;

    % Global model using srgtSRGT surrogate
    srgtOPT = srgtsRBFSetOptions(archive(:,1:dim), archive(:,dim+1));  % Set options for surrogate model
    srgtSRGT = srgtsRBFFit(srgtOPT);  % Fit surrogate model
    Tasks(1).fnc = @(x) rbf_predict(srgtSRGT.RBF_Model, srgtSRGT.P, x);  % Use rbf_predict for prediction
    
    % Local model using srgtSRGT surrogate
    srgtOPT = srgtsRBFSetOptions(archive(1:achieve_num,1:dim), archive(1:achieve_num,y_y));
    srgtSRGT = srgtsRBFFit(srgtOPT);
    Tasks(2).fnc = @(x) rbf_predict(srgtSRGT.RBF_Model, srgtSRGT.P, x);  % Use rbf_predict for prediction
    
    % Third task remains with original objective function
    Tasks(3).fnc = fobj;

    
    % Select experienced individuals
    if length_achieve < pop/4
        length_pop = length_achieve;
        sub_pop = archive(1:length_pop,:);
    else
        length_pop = pop/4;
        num_best = 1;
        num_choose = 0.5*pop;
        if length_achieve < num_choose
            sub_pop(1:num_best,1:dim) = archive(1:num_best,1:dim);
            sub_pop1 = archive(num_best+1:length_achieve,1:dim);
            rndlist_ = randperm(length_achieve-num_best);
            sub_pop(num_best+1:length_pop,1:dim) = sub_pop1(rndlist_(1:length_pop-num_best),:);
        else
            sub_pop(1:num_best,1:dim) = archive(1:num_best,1:dim);
            sub_pop1 = archive(num_best+1:num_choose,1:dim);
            rndlist_ = randperm(num_choose-num_best);
            sub_pop(num_best+1:length_pop,1:dim) = sub_pop1(rndlist_(1:length_pop-num_best),:);
        end
    end
    
    % Normalization [0,1]
    sub_pop2(1:length_pop,1:dim) = (sub_pop(1:length_pop,1:dim) - minrange)./y;
    
    % Update parameters
    if generation > toall_distance
        toall_distance = toall_distance + distance_m;
        mu = mu + 1;
        mum = mum + 1;
    end
    
    % GMFEA optimization
    data_GMFEA = GMFEA(Tasks, pop, gen, rmp, sub_pop2, mu, mum);
    
    % Evaluate new solutions
    for i = 1:2
        nvars = data_GMFEA.bestInd_data(1,i).rnvec;
        vars = y.*nvars + minrange;
        new_fit = fobj(vars);
        archive(length_achieve+i,1:dim) = vars;
        archive(length_achieve+i,dim+1) = new_fit;
        NFEs = NFEs + 1;
        if NFEs <= MaxFEs
            cg_curve(1,NFEs) = min(min(archive(:,dim+1)), cg_curve(1,max(1,NFEs-1)));
        end
    end
    
    % Update and sort archive
    archive = unique(archive,'rows');
    [~,yy] = sort(archive(:,dim+1));
    archive = archive(yy,:);
    best_one = archive(1,:);
    
    generation = generation + 1;

    % Optional progress display
    if mod(NFEs, 100) == 0
        disp(['MS-MTO -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
    end
    
end

end