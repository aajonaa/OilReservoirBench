function resetNPVTracking(popSize)
%% Function to reset NPV tracking for new optimization run
%
% This function resets the global NPV tracking variables used by evaluateNPV.m
% to ensure each optimization run starts with fresh tracking.
%
% USAGE:
%   resetNPVTracking(popSize)  % Call at the start of each optimization run
%
% INPUTS:
%   popSize - Population size to distinguish initial pop from evolution phase

    global NPV_EVAL_COUNT NPV_BEST_SO_FAR NPV_POP_SIZE NPV_INIT_COMPLETE
    NPV_EVAL_COUNT = 0;
    NPV_BEST_SO_FAR = -inf;
    NPV_INIT_COMPLETE = false;

    if nargin >= 1 && ~isempty(popSize)
        NPV_POP_SIZE = popSize;
        fprintf('=== NPV Tracking Reset | Pop Size: %d | Total FEs: Initial Pop (1-%d) + Evolution (%d+) ===\n', ...
            popSize, popSize, popSize + 1);
    else
        NPV_POP_SIZE = [];
        fprintf('=== NPV Tracking Reset for New Optimization Run ===\n');
    end
end
