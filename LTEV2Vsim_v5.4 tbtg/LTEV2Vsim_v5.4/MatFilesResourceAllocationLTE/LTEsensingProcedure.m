function [timeManagement,stationManagement,sinrManagement] = LTEsensingProcedure(timeManagement,stationManagement,sinrManagement,simParams,phyParams,appParams,outParams)
% Sensing-based autonomous resource reselection algorithm (3GPP MODE 4)
% as from 3GPP TS 36.321 and TS 36.213
% Resources are allocated for a Resource Reselection Period (SPS)
% Sensing is performed in the last 1 second
% Map of the received power and selection of the best 20% transmission hypothesis
% Random selection of one of the M best candidates
% The selection is rescheduled after a random period, with random
% probability controlled by the input parameter 'probResKeep'

% Calculate current T within the NbeaconsT
currentT = mod(timeManagement.elapsedTime_subframes-1,appParams.NbeaconsT)+1; 

%% PART 1: Update the sensing matrix
% The sensingMatrix is a 3D matrix with
% 1st D -> Number of values to be stored in the time domain, corresponding
%          to the standard duration of 1 second, of size ceil(1/Tbeacon)
% 2nd D -> BRid, of size Nbeacons
% 3rd D -> IDs of vehicles

% Array of BRids in the current subframe 
BRids_currentSF = ((currentT-1)*appParams.NbeaconsF+1):(currentT*appParams.NbeaconsF);

% A shift is performed to the estimations (1st dimension) corresponding 
% to the BRids in the current subframe for all vehicles
stationManagement.sensingMatrixLTE(:,BRids_currentSF,:) = circshift(stationManagement.sensingMatrixLTE(:,BRids_currentSF,:),1);

% The values in the first position of the 1st dimension (means last measurement) of
% the BRids in the current subframe are reset for all vehicles
%sensedPowerCurrentSF = 0;
% Refactoring in Version 5.3.1_3
sensedPowerCurrentSF = zeros(length(BRids_currentSF),length(stationManagement.activeIDsLTE));

%stationManagement.sensingMatrix(1,BRids_currentSF,:) = 0;
% In case, the values will be hereafter filled with the latest measurements

% Update of the sensing matrix
% First the LTE to LTE sensed power is saved in sensedPowerCurrentSF
if ~isempty(stationManagement.transmittingIDsLTE)   
    
    if isempty(sinrManagement.sensedPowerByLteNo11p)                
        sensedPowerCurrentSF = sensedPowerLTE(stationManagement,sinrManagement,appParams,phyParams);
    else        
        sensedPowerCurrentSF = sinrManagement.sensedPowerByLteNo11p;
    end
else
    % if there are no LTE transmissions, the sensedPowerCurrentSF remains 0
end

% sensedPowerCurrentSF = sensedPowerCurrentSF + repmat((sinrManagement.coex_averageSFinterfFrom11pToLTE(stationManagement.activeIDsLTE))',appParams.NbeaconsF,1);
% Possible addition of 11p interfrence
if simParams.technology~=4 || simParams.coexMethod~=3 || ~simParams.coexC_11pDetection
    interfFrom11p = (sinrManagement.coex_averageSFinterfFrom11pToLTE(stationManagement.activeIDsLTE));
    sensedPowerCurrentSF = sensedPowerCurrentSF + repmat(interfFrom11p',appParams.NbeaconsF,1);
else
    % In case of method C, 11p interference is not added if an 11p
    % transmission has been detected
    interfFrom11p = (sinrManagement.coex_averageSFinterfFrom11pToLTE(stationManagement.activeIDsLTE)) .* ~sinrManagement.coex_lteDetecting11pTx(stationManagement.activeIDsLTE);
    sensedPowerCurrentSF = sensedPowerCurrentSF + repmat(interfFrom11p',appParams.NbeaconsF,1);
    sinrManagement.coex_lteDetecting11pTx(:,:) = false;
end

% Small interference is changed to 0 to avoid small interference affecting
% the allocation process
sensedPowerCurrentSF(sensedPowerCurrentSF<phyParams.Pnoise_MHz) = 0;

% Sensign matrix updated
stationManagement.sensingMatrixLTE(1,BRids_currentSF,stationManagement.activeIDsLTE) = sensedPowerCurrentSF;
    
%% PART 2: Update the knownUsedMatrix (i.e., the status as read from the SCI messages)
%
% Cycle that updates per each vehicle and BR the knownUsedMatrix
%  knownUsedMatrix = zeros(appParams.Nbeacons,simValues.maxID);
if ~isempty(stationManagement.transmittingIDsLTE) 

    % Reset of matrix of received SCIs for the current subframe
    if simParams.technology==4 && simParams.coexMethod==6
        stationManagement.coexF_knownUsed(BRids_currentSF,:) = 0;
    end
    
    for i = 1:length(stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE)
        idVtx = stationManagement.transmittingIDsLTE(i);
        indexVtxLte = stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE(i);
        BRtx = stationManagement.BRid(idVtx);
        for indexNeighborsOfVtx = 1:length(stationManagement.neighborsIDLTE(indexVtxLte,:))
           idVrx = stationManagement.neighborsIDLTE(indexVtxLte,indexNeighborsOfVtx);
           if idVrx<=0
               break;
           end
           % IF the SCI is transmitted in this subframe AND if it is correctly
           % received AND the corresponding value of 'knownUsedMatrix' is lower
           % than what sent in the SCI (means the value is not updated)
           % THEN the corresponding value of 'knownUsedMatrix' is updated
           %??? ?????? ??????????????? SCI??? ???????????? ???????????? ???????????? 
           %'knownUsedMatrix'??? ?????? ?????? SCI?????? ????????? ????????? ?????????(?????? ?????????????????? ????????? ?????? ???)
           %'knownUsedMatrix'??? ?????? ?????? ?????????????????????. - hj
           if stationManagement.correctSCImatrixLTE(i,indexNeighborsOfVtx) == 1 
               % Matrix registering the received SCIs
               if simParams.technology==4 && simParams.coexMethod==6
                   stationManagement.coexF_knownUsed(BRtx,idVrx) = 1;
               end
               if stationManagement.knownUsedMatrixLTE(BRtx,idVrx) < stationManagement.resReselectionCounterLTE(idVtx)
                    stationManagement.knownUsedMatrixLTE(BRtx,idVrx) = stationManagement.resReselectionCounterLTE(idVtx);
               end
               % If overlap of beacon resources is allowed, the SCI
               % information is used to update partially overlapping beacon
               % resources
               if phyParams.BRoverlapAllowed
                   for indexBR=BRids_currentSF
                       if (indexBR<BRtx && indexBR+phyParams.NsubchannelsBeacon-1>=BRtx) || ...
                          (indexBR>BRtx && indexBR-phyParams.NsubchannelsBeacon+1<=BRtx)
                           if stationManagement.knownUsedMatrixLTE(indexBR,idVrx) < stationManagement.resReselectionCounterLTE(idVtx)
                                stationManagement.knownUsedMatrixLTE(indexBR,idVrx) = stationManagement.resReselectionCounterLTE(idVtx);
                           end
                       end
                   end
               end
           % NOTE: the SCI is here assumed to advertise the current value of the reselection
           % counter, which is an approximation of what in TS 36.213, Table 14.2.1-2
           end
        end
    end
end

%% Removed from here since version 5.2.9 - now in the main
% %% PART 3: Calculation of the channel busy ratio
% % The channel busy ratio is calculated, if needed, every subframe for those
% % nodes that have a packet generated in the subframe that just ended
% if ~isempty(sinrManagement.cbrLTE)
%     [timeManagement,stationManagement,sinrManagement] = cbrUpdateLTE(timeManagement,stationManagement,sinrManagement,appParams,simParams,phyParams,outParams);
% end
%%

end

