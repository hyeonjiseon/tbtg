close all    % Close all open figures
clear        % Reset variables
clc          % Clear the command window

%LTEV2Vsim('help');

%% LTE Autonomous (3GPP Mode 4) - on a subframe basis
% Autonomous allocation algorithm defined in 3GPP standard
%density = [200, 400, 600, 800]; %density(i)
%for i = 1:length(density)
    LTEV2Vsim('BenchmarkPoisson.cfg','simulationTime',1,'rho', 200,...
        'BRAlgorithm',18,'camDiscretizationType', 'allSteps', ...
        'NLanes', 4,'roadLength', 3000, 'roadWidth', 4, 'TypeOfScenario', 'ETSI-Highway',...
        'printUpdateDelay', true);
%end