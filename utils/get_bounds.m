function [Xmin, Xmax] = variable_domain(fname)
    switch upper(fname)
        case 'GRIEWANK'
            Xmin = -600;
            Xmax = 600;
        case 'ACKLEY'
            Xmin = -32;
            Xmax = 32;
        case 'ROSENBROCK'
            Xmin = -2.048;
            Xmax = 2.048;
        case 'ELLIPSOID'
            Xmin = -100;
            Xmax = 100;
        case 'RASTRIGIN'
            Xmin = -5.12;
            Xmax = 5.12;
        otherwise
            error('Unknown function name');
    end
end 