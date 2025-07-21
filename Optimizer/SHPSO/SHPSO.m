function [cg_curve] = SHPSO(N, MaxFEs, LB, UB, dim, fobj)

LB = repmat(LB, 1, dim);
UB = repmat(UB, 1, dim);

% -------------- parameter initialization----------------------
NFEs = 0;
cg_curve = zeros(1,MaxFEs);

% SHPSO parameters
ps = 50;                               % population size
cc = [2.05 2.05];                      % acceleration constants  
iwt = 0.7298;                          % inertia weight

% Training sample parameters
if dim < 100
    gs = 100;                          % < 100 dimension
else
    gs = 150;                          % >= 100 dimension
end

% Initialize velocity bounds
mv = 0.5*(UB-LB);
VRmin = repmat(LB,ps,1);
VRmax = repmat(UB,ps,1);            
Vmin = repmat(-mv,ps,1);
Vmax = -Vmin;

% -------------- generate initial samples-----------------------
sam = repmat(LB,ps,1) + (repmat(UB,ps,1)-repmat(LB,ps,1)).*lhsdesign(ps,dim);
fit = zeros(ps,1);

for i = 1:ps
    fit(i) = fobj(sam(i,:));  
    NFEs = NFEs + 1;
    cg_curve(1,NFEs) = min(fit(1:i));
end

% Build database
hx = sam; 
hf = fit;                                            
[hf,sidx] = sort(hf);                                         
hx = hx(sidx,:);  

% Initialize SHPSO
vel = Vmin + 2.*Vmax.*rand(ps,dim);    % initialize velocity
pos = hx(1:ps,:); 
e = hf(1:ps);          
pbest = pos;  
pbestval = e;              
[gbestval,gbestid] = min(pbestval);
gbest = pbest(gbestid,:);              
gbestrep = repmat(gbest,ps,1);
besty = 1e200;
bestp = zeros(1,dim);

gen = 1;
%% Main loop
while NFEs < MaxFEs
    try
        % Sample training samples
        [ghf,id] = sort(hf);              
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
        NFEs = NFEs + 1;
        
        % Update convergence curve
        if NFEs == 1
            cg_curve(1,NFEs) = besty;
        else
            cg_curve(1,NFEs) = min(cg_curve(1,NFEs-1), besty);
        end

        % Update database
        [~,ih,~] = intersect(hx,bestp,'rows');
        if isempty(ih)
            hx = [hx;bestp];  
            hf = [hf;besty];
        end

        % Update best solution
        if besty < besty_old      
            bestprep = repmat(bestp,ps,1);
        else
            besty = besty_old;
            bestp = bestp_old;
            bestprep = repmat(bestp_old,ps,1);
        end

        % Update SHPSO
        if besty < gbestval                             
            [~,ip,~] = intersect(pbest,gbest,'rows');
            if ~isempty(ip)
                pbest(ip,:) = bestp;
                pbestval(ip) = besty;                        
                gbestrep = bestprep;
            end
        end

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
        candidx = find(e < pbestval);
        
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
            if NFEs >= MaxFEs
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
            if kp <= size(pbest,1) && e_trmem < pbestval(kp)
                pbest(kp,:) = pos_trmem(k,:);
                pbestval(kp) = e_trmem;
            end
            
            % Update convergence curve
            cg_curve(1,NFEs) = min([cg_curve(1,NFEs-1), e_trmem]);
        end

        % Update gbest
        [gbestval,tmp] = min(pbestval);
        gbest = pbest(tmp,:);
        gbestrep = repmat(gbest,ps,1);

        % Optional progress display
        if mod(NFEs, 100) == 0
            disp(['SHPSO -- NFE: ' num2str(NFEs) ', Best: ' num2str(cg_curve(1,NFEs))]);
        end

    catch ME
        warning('Error in iteration: %s', ME.message);
        continue;
    end
    
    gen = gen + 1;
end

% Ensure cg_curve is filled to MaxFEs
if NFEs < MaxFEs
    cg_curve(NFEs+1:MaxFEs) = cg_curve(NFEs);
end

end