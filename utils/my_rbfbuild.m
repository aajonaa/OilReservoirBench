function [model, time] =my_rbfbuild(Xtr, Ytr, bf_type, bf_c, usePolyPart, verbose)
%Xtr=X; Ytr=Y; bf_type='G'; bf_c=1,usePolyPart= 2, verbose=0;
% RBFBUILD %% Add small regularization by Jona 2025-2-22
% Builds a Radial Basis Function (RBF) interpolant using training data

% Call
%   [model, time] = rbf_build(Xtr, Ytr, bf_type, bf_c, usePolyPart, verbose)
%   [model, time] = rbf_build(Xtr, Ytr, bf_type, bf_c, usePolyPart)
%   [model, time] = rbf_build(Xtr, Ytr, bf_type, bf_c)
%   [model, time] = rbf_build(Xtr, Ytr, bf_type)
%   [model, time] = rbf_build(Xtr, Ytr)
%
% Input
% Xtr, Ytr    : Training data points (Xtr(i,:), Ytr(i)), i = 1,...,n
%               Note that the input variables must be scaled to e.g. [0,1]
%               or [-1,1] for better predictive performance.
% bf_type     : Type of the basis functions (default = 'MQ'):
%               'BH' = Biharmonic
%               'MQ' = Multiquadric
%               'IMQ' = Inverse Multiquadric
%               'TPS' = Thin plate spline
%               'G' = Gaussian
% bf_c        : Parameter c value (default = 1)
% usePolyPart : Use also the polynomial term P of the model Y = P + RBF
%               (default = 0, do not use)
% verbose     : Set to 0 for no verbose (default = 1)
%
% Output
% model     : RBF model - a struct with the following elements:
%    n      : Number of data points in the training data set
%    meanY  : Mean of Ytr
%    bf_type: Type of the basis functions
%    bf_c   : Parameter c value
%    poly   : Use also the polynomial term
%    coefs  : Coefficients of the model
% time      : Execution time
%
% Please give a reference to the software web page in any publication
% describing research performed using the software, e.g. like this:
% Jekabsons G. Radial Basis Function interpolation for Matlab, 2009,
% available at http://www.cs.rtu.lv/jekabsons/

% This source code is tested with Matlab version 7.1 (R14SP3).

% =========================================================================
% RBF interpolation
% Version: 1.1
% Date: August 12, 2009
% Author: Gints Jekabsons (gints.jekabsons@rtu.lv)
% URL: http://www.cs.rtu.lv/jekabsons/
%
% Copyright (C) 2009  Gints Jekabsons
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program. If not, see <http://www.gnu.org/licenses/>.
% =========================================================================
%
if nargin < 2
    error('Too few input arguments.');
else
    
    [n, d] = size(Xtr);
    [ny, dy] = size(Ytr);
    if (n < 2) || (d < 1) || (ny ~= n) || (dy ~= 1)
        error('Wrong training data sizes.');
    end
    
    if nargin < 3
        bf_type = 'MQ';
    end
    if nargin < 4
        bf_c = 1;
    end
    if nargin < 5
        usePolyPart = 0;
    end
    if nargin < 6
        verbose = 1;
    end
    
    tic;
    %}
    model.n = n;
    model.meanY = mean(Ytr);
    model.bf_type = bf_type;
    model.bf_c = bf_c;
    model.poly = usePolyPart;
    
    %calculate and transform distances between all the points in the training data
    dist = zeros(n, n);
    switch upper(model.bf_type)
        case 'BH'
            if verbose
                fprintf('Building RBF (biharmonic) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = norm(Xtr(i,:) - Xtr(j,:));
                %end
                dist(i, i:n) = sqrt(sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2));
                dist(i+1:n, i) = dist(i, i+1:n);
            end
        case 'IMQ'
            if verbose
                fprintf('Building RBF (inverse multiquadric) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = 1 / sqrt(sum((Xtr(i,:) - Xtr(j,:)).^2) + bf_c^2);
                %end
                dist(i, i:n) = 1 ./ sqrt(sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2) + bf_c^2);
                dist(i+1:n, i) = dist(i, i+1:n);
            end
        case 'CUB'
            bf_c = 0;
            if verbose
                fprintf('Building RBF (cubic) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = 1 / sqrt(sum((Xtr(i,:) - Xtr(j,:)).^2) + bf_c^2);
                %end
                dist(i, i:n) = sqrt(sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2) + bf_c^2).^3;
                dist(i+1:n, i) = dist(i, i+1:n);
            end
        case 'TPS'
            if verbose
                fprintf('Building RBF (thin plate spline) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = sum((Xtr(i,:) - Xtr(j,:)).^2);
                %    dist(i, j) = (dist(i, j) + bf_c^2) * log(sqrt(dist(i, j) + bf_c^2));
                %end
                dist(i, i:n) = sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2);
                dist(i, i:n) = (dist(i, i:n) + bf_c^2) .* log(sqrt(dist(i, i:n) + bf_c^2));
                dist(i+1:n, i) = dist(i, i+1:n);
            end
        case 'G'
            if verbose
                fprintf('Building RBF (Gaussian) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = exp(-sum((Xtr(i,:) - Xtr(j,:)).^2) / (2*bf_c^2));
                %end
                dist(i, i:n) = exp(-sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2) / (2*bf_c^2));
                dist(i+1:n, i) = dist(i, i+1:n);
            end
        otherwise %MQ
            if verbose
                fprintf('Building RBF (multiquadric) model...\n');
            end
            for i = 1 : n
                %for j = i : n
                %    dist(i, j) = sqrt(sum((Xtr(i,:) - Xtr(j,:)).^2) + bf_c^2);
                %end
                dist(i, i:n) = sqrt(sum((repmat(Xtr(i,:),n-i+1,1) - Xtr(i:n,:)).^2,2) + bf_c^2);
                dist(i+1:n, i) = dist(i, i+1:n);
            end
    end
    % condnum=cond(dist);
    model.dist=dist;


%     % Add regularization parameter 2025-2-22
%     lambda = 1e-6;  % Small regularization term
% 
%     %calculate coefs
%     if model.poly == 0
%         % model.coefs = dist \ (Ytr - model.meanY);
%         % Add regularization to the distance matrix
%         dist_reg = dist + lambda * eye(size(dist));
%         model.coefs = dist_reg \ (Ytr - model.meanY);
%     else
%         if model.poly == 1
% %             for i=1:n
% %                 Xt(i,:)=Xtr(i,:);
% %             end
%             % Xt=Xtr;
%             % A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros(d+1,d+1)];
%             % model.coefs  = A \ [Ytr; zeros(d+1,1)];
%             %             eta = sqrt((10^-16) * norm(A, 1) * norm(A, inf));
%             %             pdim=d+1;
%             %             model.coefs= (A + eta * eye(n + pdim)) \[Ytr;zeros(pdim,1)];
% 
%             Xt = Xtr;
%             A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros(d+1,d+1)];
%             % Add regularization to the entire matrix
%             A_reg = A + lambda * eye(size(A));
%             model.coefs = A_reg \ [Ytr; zeros(d+1,1)];
%         end
%         if model.poly == 2
%             % Xt=dace_regpoly2(Xtr);
%             % Xt(:,1)=[];
%             % A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros((d+1)*(d+2)/2,(d+1)*(d+2)/2)];
%             % model.coefs  = A \ [Ytr; zeros((d+1)*(d+2)/2,1)];
%             % model.A  = A;
%             Xt = dace_regpoly2(Xtr);
%             Xt(:,1) = [];
%             pdim = (d+1)*(d+2)/2;
%             A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros(pdim,pdim)];
%             % Add regularization to the entire matrix
%             A_reg = A + lambda * eye(size(A));
%             model.coefs = A_reg \ [Ytr; zeros(pdim,1)];
%             model.A = A_reg;
%         end
%     end


    % LSQR parameters
    tol = 1e-10;        % Tolerance for LSQR
    maxit = 1000;       % Maximum iterations for LSQR
    lambda = 1e-6;      % Regularization parameter

    %calculate coefs
    if model.poly == 0
        % Add regularization and use LSQR
        dist_reg = dist + lambda * eye(size(dist));
        [model.coefs, flag, relres, iter] = lsqr(dist_reg, (Ytr - model.meanY), tol, maxit);
        
        % Store LSQR information
        model.lsqr_info.flag = flag;
        model.lsqr_info.relres = relres;
        model.lsqr_info.iter = iter;
        
        if verbose && flag ~= 0
            fprintf('LSQR warning: flag = %d, relres = %e, iter = %d\n', flag, relres, iter);
        end
    else
        if model.poly == 1
            Xt = Xtr;
            A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros(d+1,d+1)];
            A_reg = A + lambda * eye(size(A));
            b = [Ytr; zeros(d+1,1)];
            
            % Use LSQR for the augmented system
            [model.coefs, flag, relres, iter] = lsqr(A_reg, b, tol, maxit);
            
            % Store LSQR information
            model.lsqr_info.flag = flag;
            model.lsqr_info.relres = relres;
            model.lsqr_info.iter = iter;
            
            if verbose && flag ~= 0
                fprintf('LSQR warning: flag = %d, relres = %e, iter = %d\n', flag, relres, iter);
            end
        end
        if model.poly == 2
            Xt = dace_regpoly2(Xtr);
            Xt(:,1) = [];
            pdim = (d+1)*(d+2)/2;
            A = [dist, ones(n,1), Xt; [ones(n,1), Xt]', zeros(pdim,pdim)];
            A_reg = A + lambda * eye(size(A));
            b = [Ytr; zeros(pdim,1)];
    
            % Use LSQR for the augmented system
            [model.coefs, flag, relres, iter] = lsqr(A_reg, b, tol, maxit);
            
            % Store LSQR information
            model.lsqr_info.flag = flag;
            model.lsqr_info.relres = relres;
            model.lsqr_info.iter = iter;
            model.A = A_reg;
            
            if verbose && flag ~= 0
                fprintf('LSQR warning: flag = %d, relres = %e, iter = %d\n', flag, relres, iter);
            end
        end
    end
    
    % Store additional information about the solution
    model.lambda_used = lambda;
    model.condition_number = cond(dist);
    
    time = toc;
    
    if verbose
        fprintf('Execution time: %0.2f seconds\n', time);
        fprintf('Condition number: %e\n', model.condition_number);
    end
    
end
return
