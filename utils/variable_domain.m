% func_boundary from HMS-QPSO
function [lb, ub, f_bias] = func_boundary(ifu)
    % Define bounds and f_bias for different functions
    
    switch ifu
        % 1. Shifted Sphere Function
        case 1
            lb = 100; ub = -100; f_bias = -450;
            
        % 2. Shifted Schwefel's Problem 1.2
        case 2
            lb = 100; ub = -100; f_bias = -450;
        
        % 3. Shifted Rotated High Conditioned Elliptic Function
        case 3
            lb = 100; ub = -100; f_bias = -450;
        
        % 4. Shifted Schwefel's Problem 1.2 with Noise in Fitness
        case 4
            lb = 100; ub = -100; f_bias = -450;
        
        % 5. Schwefel's Problem 2.6 with Global Optimum on Bounds
        case 5
            lb = 100; ub = -100; f_bias = -310;
        
        % Basic Functions (7):
        % 6. Shifted Rosenbrock's Function
        case 6
            lb = 100; ub = -100; f_bias = 390;
        
        % 7. Shifted Rotated Griewank's Function without Bounds
        case 7
            lb = 600; ub = 0; f_bias = -180;
        
        % 8. Shifted Rotated Ackley's Function with Global Optimum on Bounds
        case 8
            lb = 32; ub = -32; f_bias = -140;
        
        % 9. Shifted Rastrigin's Function
        case 9
            lb = 5; ub = -5; f_bias = -330;
        
        % 10. Shifted Rotated Rastrigin's Function
        case 10
            lb = 5; ub = -5; f_bias = -330;
        
        % 11. Shifted Rotated Weierstrass Function
        case 11
            lb = 0.5; ub = -0.5; f_bias = 90;
        
        % 12. Schwefel's Problem 2.13
        case 12
            lb = 100; ub = -100; f_bias = -460;
        
        % Expanded Functions (2):
        % 13. Expanded Extended Griewank's plus Rosenbrock's Function (F8F2)
        case 13
            lb = 1; ub = -3; f_bias = -130;
        
        % 14. Expanded Rotated Extended Scaffe's F6
        case 14
            lb = 100; ub = -100; f_bias = -300;
        
        % Hybrid Composition Functions (11):
        % 15. Hybrid Composition Function 1
        case 15
            lb = 5; ub = -5; f_bias = 120;
        
        otherwise
            error('Unknown function index: %d', ifu);
    end
end
