function [bestNPV, worstNPV, meanNPV, runTime, convergence] = run_SHPSO(popSize, maxFEs, lb, ub, fobj)
    % Start timer
    tic;
    
    % Determine problem dimensionality
    dim = numel(lb);

    % -------------- parameter initialization----------------------
    NFEs = 0;
    count = 0;
    convergence = zeros(1, maxFEs);

    % SHPSO parameters
    ps = popSize;                          % population size
    cc = [2.05 2.05];                      % acceleration constants  
    iwt = 0.7298;                          % inertia weight

    % Training sample parameters
    if dim < 100
        gs = 100;                          % < 100 dimension
    else
        gs = 150;                          % >= 100 dimension
    end

    % Initialize velocity bounds
    mv = 0.5*(ub-lb);
    VRmin = repmat(lb, ps, 1);
    VRmax = repmat(ub, ps, 1);            
    Vmin = repmat(-mv, ps, 1);
    Vmax = -Vmin;

    % -------------- generate initial samples-----------------------
    sam = repmat(lb, ps, 1) + (repmat(ub, ps, 1)-repmat(lb, ps, 1)).*lhsdesign(ps, dim);
    fit = zeros(ps, 1);
    best_so_far = -inf;  % Track best solution found

    for i = 1:ps
        fit(i) = fobj(sam(i,:));  
        count = count + 1;
        disp(['Current fobj count of SHPSO: ', num2str(count)]);
        NFEs = NFEs + 1;
        best_so_far = max(best_so_far, fit(i));
        convergence(NFEs) = best_so_far;
    end

    % Build database
    hx = sam; 
    hf = fit;                                            
    [hf, sidx] = sort(hf, 'descend');  % Changed to descend for maximization                                      
    hx = hx(sidx,:);  

    % Initialize SHPSO
    vel = Vmin + 2.*Vmax.*rand(ps,dim);    % initialize velocity
    pos = hx(1:ps,:); 
    e = hf(1:ps);          
    pbest = pos;  
    pbestval = e;              
    [gbestval,gbestid] = max(pbestval);  % Changed to max for maximization
    gbest = pbest(gbestid,:);              
    gbestrep = repmat(gbest,ps,1);
    besty = -inf;  % Changed to -inf for maximization
    bestp = zeros(1,dim);

    gen = 1;
    %% Main loop
    while NFEs < maxFEs
        try
            % Sample training samples
            [ghf,id] = sort(hf, 'descend');  % Changed to descend for maximization             
            gs_actual = min(gs,length(ghf));
            ghf = ghf(1:gs_actual);     
            ghx = hx(id(1:gs_actual),:);
            
            % Build RBF network
            ghxd = real(sqrt(ghx.^2*ones(size(ghx'))+ones(size(ghx))*(ghx').^2-2*ghx*(ghx')));
            spr = max(max(ghxd))/(dim*gs_actual)^(1/dim);
            if spr <= 0
                spr = 1;
            end
            net = newrbe(ghx', ghf(:)', spr);        
            modelFUN = @(x) sim(net,x');

            % Record old best
            besty_old = besty;
            bestp_old = bestp;
            
            % Optimize surrogate model
            maxgen = 50*dim; 
            minerror = 1e-6;
            [bestp,~] = SLPSO(dim,maxgen,modelFUN,minerror,ghx);    

            % Evaluate model optimum
            besty = fobj(bestp); 
            count = count + 1;
            disp(['Current fobj count of SHPSO: ', num2str(count)]);
            NFEs = NFEs + 1;
            
            % Update best-so-far and convergence curve
            best_so_far = max(best_so_far, besty);
            convergence(NFEs) = best_so_far;

            % Update database
            [~,ih,~] = intersect(hx,bestp,'rows');
            if isempty(ih)
                hx = [hx;bestp];  
                hf = [hf;besty];
            end

            % Update best solution
            if besty > besty_old  % Changed to > for maximization     
                bestprep = repmat(bestp,ps,1);
            else
                besty = besty_old;
                bestp = bestp_old;
                bestprep = repmat(bestp_old,ps,1);
            end

            % Update SHPSO
            if besty > gbestval  % Changed to > for maximization                            
                [~,ip,~] = intersect(pbest,gbest,'rows');
                if ~isempty(ip)
                    pbest(ip,:) = bestp;
                    pbestval(ip) = besty;                        
                    gbestrep = bestprep;
                end
            end

            % Update velocities and positions
            aa = cc(1).*rand(ps,dim).*(pbest-pos)+cc(2).*rand(ps,dim).*(gbestrep-pos);
            vel = iwt.*(vel+aa);                              
            vel = (vel>Vmax).*Vmax+(vel<=Vmax).*vel;
            vel = (vel<Vmin).*Vmin+(vel>=Vmin).*vel;
            pos = pos+vel;
            pos = ((pos>=VRmin)&(pos<=VRmax)).*pos...
                +(pos<VRmin).*(VRmin+0.25.*(VRmax-VRmin).*rand(ps,dim))...
                +(pos>VRmax).*(VRmax-0.25.*(VRmax-VRmin).*rand(ps,dim));

            % Fitness estimation and prescreening
            e = modelFUN(pos);
            candidx = find(e > pbestval);  % Changed to > for maximization
            
            % Skip if no candidates found
            if isempty(candidx)
                continue;
            end
            
            % Ensure candidx is within bounds
            candidx = candidx(candidx <= size(pos,1));
            if isempty(candidx)
                continue;
            end
            
            pos_trmem = pos(candidx, :);

            % Check for duplicates with bounds checking
            [~,ih,ip] = intersect(hx,pos_trmem,'rows');
            if ~isempty(ip)
                valid_idx = ip <= length(candidx);
                ip = ip(valid_idx);
                ih = ih(valid_idx);
                
                if ~isempty(ip)
                    pos_trmem(ip,:) = [];
                    if ~isempty(candidx)
                        e(candidx(ip)) = hf(ih);
                    end
                    candidx(ip) = [];
                end
            end

            % Evaluate prescreened candidates
            for k = 1:size(pos_trmem,1)
                if NFEs >= maxFEs
                    break;
                end
                
                % Ensure k is within bounds
                if k > length(candidx)
                    break;
                end
                
                e_trmem = fobj(pos_trmem(k,:));
                NFEs = NFEs + 1;
                
                % Update database
                hx = [hx;pos_trmem(k,:)];
                hf = [hf;e_trmem];
                
                % Update pbest with bounds checking
                kp = candidx(k);
                if kp <= size(pbest,1) && e_trmem > pbestval(kp)  % Changed to > for maximization
                    pbest(kp,:) = pos_trmem(k,:);
                    pbestval(kp) = e_trmem;
                end
                
                % Update best-so-far and convergence curve
                best_so_far = max(best_so_far, e_trmem);
                convergence(NFEs) = best_so_far;
            end

            % Update gbest
            [gbestval,tmp] = max(pbestval);  % Changed to max for maximization
            gbest = pbest(tmp,:);
            gbestrep = repmat(gbest,ps,1);

            % Optional progress display
            if mod(NFEs, 100) == 0
                disp(['SHPSO -- NFE: ' num2str(NFEs) ', Best: ' num2str(best_so_far)]);
            end

        catch ME
            warning('Error in iteration: %s', ME.message);
            continue;
        end
        
        gen = gen + 1;
    end

    % Fill remaining convergence curve values if needed
    if NFEs < maxFEs
        convergence(NFEs+1:maxFEs) = best_so_far;
    end

    % Compute final statistics
    bestNPV = best_so_far;
    worstNPV = min(hf);
    meanNPV = mean(hf);
    runTime = toc;

    % Print final results
    fprintf('SHPSO run: Best NPV = %.2e, Worst NPV = %.2e, Mean NPV = %.2e, Runtime = %.2f sec\n', ...
        bestNPV, worstNPV, meanNPV, runTime);
end