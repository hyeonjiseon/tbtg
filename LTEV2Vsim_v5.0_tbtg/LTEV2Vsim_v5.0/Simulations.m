close all    % Close all open figures
clear        % Reset variables
clc          % Clear the command window

%LTEV2Vsim('help');

%% LTE Autonomous (3GPP Mode 4) - on a subframe basis
% Autonomous allocation algorithm defined in 3GPP standard
%density = [50, 100, 200]; %density(i)

%for i = 1:length(density)
    LTEV2Vsim('BenchmarkPoisson.cfg','simulationTime',10, 'rho', 50,...
        'BRAlgorithm',18, 'camDiscretizationType', 'allSteps');
%end
%'MCS_LTE', 7, 'printCBR', true
