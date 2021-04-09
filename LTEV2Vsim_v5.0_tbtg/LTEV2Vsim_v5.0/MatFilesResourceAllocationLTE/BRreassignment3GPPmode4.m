function [timeManagement,stationManagement,sinrManagement,Nreassign] = BRreassignment3GPPmode4(timeManagement,stationManagement,sinrManagement,simParams,phyParams,appParams,outParams)
% Sensing-based autonomous resource reselection algorithm (3GPP MODE 4)
% as from 3GPP TS 36.321 and TS 36.213
% Resources are allocated for a Resource Reselection Period (SPS)
% Sensing is performed in the last 1 second
% Map of the received power and selection of the best 20% transmission hypothesis
% Random selection of one of the M best candidates
% The selection is rescheduled after a random period, with random
% probability controlled by the input parameter 'probResKeep'

% ==============
% Copyright (C) Alessandro Bazzi, University of Bologna, and Alberto Zanella, CNR
% 
% All rights reserved.
% 
% Permission to use, copy, modify, and distribute this software for any 
% purpose without fee is hereby granted, provided that this entire notice 
% is included in all copies of any software which is or includes a copy or 
% modification of this software and in all copies of the supporting 
% documentation for such software.
% 
% THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED 
% WARRANTY. IN PARTICULAR, NEITHER OF THE AUTHORS MAKES ANY REPRESENTATION 
% OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY OF THIS SOFTWARE 
% OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
% 
% Project: LTEV2Vsim
% ==============

activeIdsLTE = stationManagement.activeIDsLTE;
subframeNextPacket = mod(ceil(timeManagement.timeNextPacket/phyParams.Tsf)-1,(appParams.NbeaconsT))+1;
NbeaconsT = appParams.NbeaconsT;
NbeaconsF = appParams.NbeaconsF;

% Calculate current T within the NbeaconsT
currentT = mod(timeManagement.elapsedTime_subframes-1,NbeaconsT)+1; 

% Number of beacons per beacon period
Nbeacons = NbeaconsT*NbeaconsF;

% The best 20% (modifiable by input) is selected as pool as in TS 36.213
% If T1==1 and T2==100, Mbest is the 20% of all beacon resources
% In the case T1>1 and/or T2<100, Mbest is the 20% of the consequent number
% of resources
MBest = ceil(Nbeacons * ((simParams.subframeT2Mode4-simParams.subframeT1Mode4+1)/100) * simParams.ratioSelectedMode4);

% Reset number of successfully reassigned vehicles
Nreassign = 0;

%% Update the sensing matrix
% The sensingMatrix is a 3D matrix with
% 1st D -> Number of values to be stored in the time domain, corresponding
%          to the standard duration of 1 second, of size ceil(1/Tbeacon)
% 2nd D -> BRid, of size Nbeacons
% 3rd D -> IDs of vehicles

% Array of BRids in the current subframe 
BRids_currentSF = ((currentT-1)*NbeaconsF+1):(currentT*NbeaconsF);

% A shift is performed to the estimations (1st dimension) corresponding 
% to the BRids in the current subframe for all vehicles
stationManagement.sensingMatrixLTE(:,BRids_currentSF,:) = circshift(stationManagement.sensingMatrixLTE(:,BRids_currentSF,:),1);

% The values in the first position of the 1st dimension (means last measurement) of
% the BRids in the current subframe are reset for all vehicles
%sensingMatrix(1,BRids_currentSF,:) = 0;
% These values will be hereafter filled with the latest measurements

% Update of the sensing matrix
if ~isempty(stationManagement.transmittingIDsLTE)       
    if isempty(sinrManagement.sensedPowerByLteNo11p)                
        %transmittingID가 전송하는 걸 다른 차랑들이 어떤 power로 받는 지 - hj
        sensedPowerCurrentSF = sensedPowerLTE(stationManagement,sinrManagement,appParams,phyParams);
    else        
        sensedPowerCurrentSF = sinrManagement.sensedPowerByLteNo11p;        
    end

    % If the received power measured on that resource is lower than
    % a threshold, it is assumed that no power is measured
    sensedPowerCurrentSF(sensedPowerCurrentSF<phyParams.Pnoise_MHz) = 0;

    stationManagement.sensingMatrixLTE(1,BRids_currentSF,stationManagement.activeIDsLTE) = sensedPowerCurrentSF;
    
end

%hyeonji - 기존 RRI 부분이니까 다시 작성해야 함
% % Cycle that updates per each vehicle and BR the knownUsedMatrix
% % knownUsedMatrix = zeros(appParams.Nbeacons,simValues.maxID);
% if ~isempty(stationManagement.transmittingIDsLTE)     
%     for i = 1:length(stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE)
%         idVtx = stationManagement.transmittingIDsLTE(i);
%         indexVtxLte = stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE(i);
%         BRtx = stationManagement.BRid(idVtx);
%         for indexNeighborsOfVtx = 1:length(stationManagement.neighborsIDLTE(indexVtxLte,:)) %transmittingID의 이웃들 갯수 - hj
%            idVrx = stationManagement.neighborsIDLTE(indexVtxLte,indexNeighborsOfVtx); %transmittingID의 neighborsID - hj
%            if idVrx<=0 %neighborsID가 없으면 break - hj
%                break;
%            end
%            % IF the SCI is transmitted in this subframe AND if it is correctly
%            % received AND the corresponding value of 'knownUsedMatrix' is lower
%            % than what sent in the SCI (means the value is not updated)
%            % THEN the corresponding value of 'knownUsedMatrix' is updated
%            % 이 subframe에 sci가 전송되어 정확하게 수신되었다 &&
%            % knownUsedMatrix의 (transmittingID, neigborsID)가 transmittingID의 RC값보다 작다
%            % -> knowUsedMatrix를 transmittingID의 RC값으로 update한다. - hj
%            if stationManagement.correctSCImatrixLTE(i,indexNeighborsOfVtx) == 1 && ...
%                   stationManagement.knownUsedMatrixLTE(BRtx,idVrx) < stationManagement.resReselectionCounterLTE(idVtx)
%               %i번째 tx의 indexNeighborsOfVtx번째 neighbors에 sci가 수신되고 
%               %knownUsedMatrix(txID의 BRid, neighborsID)가 tx의 ReselectionCounter보다 작으면 - hj
%               %이웃이 쏜 SCI가 해독됐고, 내 이웃들이 현재 쏘고 있는 자원칸을 이웃들이 얼마나 더 쓸 건지,
%               %이웃이 계쏙 쓰면 그것을 제외하기 위함 - jh
%                stationManagement.knownUsedMatrixLTE(BRtx,idVrx) = stationManagement.resReselectionCounterLTE(idVtx);
%                %knownUsedMatrix(txID의 BRid, neighborsID)에 그 RC값 update - hj
%            % NOTE: the SCI is here assumed to advertise the current value of the reselection
%            % counter, which is an approximation of what in TS 36.213, Table 14.2.1-2
%            elseif stationManagement.correctSCImatrixLTE(i, indexNeighborsOfVtx) == 0 
%                stationManagement.knownUsedMatrixLTE(BRtx, idVrx) = 0;
%                %이 subframe에 sci가 전송되어 정확하게 수신되지 않았으면 knownUsedMatrix값을 0으로 둔다. - hj
%            end
%         end
%     end
% end

%hyeonji - packetInterval에 따라서 바뀌는 RRP로 예약
if ~isempty(stationManagement.transmittingIDsLTE)     
    for i = 1:length(stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE)
        idVtx = stationManagement.transmittingIDsLTE(i);
        indexVtxLte = stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE(i);
        BRtx = stationManagement.BRid(idVtx);
        RRItx = stationManagement.RRItx(idVtx);
        %hyeonji - transmittingID의 BRid에서 RRP만큼 떨어진 곳으로 예약
        %예약된 거 있나 비워주는 작업이 필요할까?
        stationManagement.ReserveRRPMatrix(BRtx,RRItx,idVtx) = 1; %일단 0.1~1까지 0.1 단위로만 된다 생각해보자 - hj
        for indexNeighborsOfVtx = 1:length(stationManagement.neighborsIDLTE(indexVtxLte,:)) %transmittingID의 이웃들 갯수 - hj
           idVrx = stationManagement.neighborsIDLTE(indexVtxLte,indexNeighborsOfVtx); %transmittingID의 neighborsID - hj
           if idVrx<=0 %neighborsID가 없으면 break - hj
               break;
           end          
           if stationManagement.correctSCImatrixLTE(i,indexNeighborsOfVtx) == 1 % 이 subframe에 sci가 전송되어 정확하게 수신되었다
               %hyeonji - 속도에 따른 RRP만큼 떨어진 newBRid, RRP, neighborsID에 1 표시한 RRPMatrix                   
               [BR, RRP] = find(stationManagement.ReserveRRPMatrix(:,:,idVtx)==1); %송신자 입장에서 예약한 게 수신됨 
               stationManagement.knownRRPMatrix(BR, RRP, idVrx) = 1; %수신자 입장에서 RRP 이후 같은 위치 BRid에 체크                            
           end
        end
%         %hyeonji - BRid 같다고 RC값 떨어뜨리면 뛰어 넘었을 때도 떨어지게 되니까 추가된 만큼 더해주기      
%         if RRP > 1
%            stationManagement.resReselectionCounterLTE(idVtx) = stationManagement.resReselectionCounterLTE(idVtx) + (RRP - 1);
%         end
    end
end


%% Update the resReselectionCounter and evaluate which vehicles need reselection
% Calculate scheduledID
inTheLastSubframe = -1*ones(length(subframeNextPacket),1);
inTheLastSubframe(activeIdsLTE) = (subframeNextPacket(activeIdsLTE)==currentT);

% Update resReselectionCounter
% Reduce the counter by one to all those that have a packet generated in
% the last subframe
% Among them, those that have reached 0 need to be reset between min and max
% stationManagement.resReselectionCounterLTE(activeIdsLTE) = stationManagement.resReselectionCounterLTE(activeIdsLTE)-inTheLastSubframe(activeIdsLTE);

%hyeonji - 매 패킷 생성 시 RC값 떨어지니까 패킷이 안 생기게 해야 할 것 같다
%hyeonji - 100ms 단위일 땐 모든 차량이 100ms 안에 한 번씩 전송하니까 이 전송들이 다 끝나고 나면 한번에 RC값을 내려줬다.
%          이게 언제 뛰어 넘어야 한다고 기준을 잡아줘야 할 것 같은데..



if timeManagement.elapsedTime_subframes <=100
    stationManagement.resReselectionCounterLTE(activeIdsLTE) = stationManagement.resReselectionCounterLTE(activeIdsLTE)-inTheLastSubframe(activeIdsLTE);
else
    for j = 1:length(activeIdsLTE)    
        if inTheLastSubframe(j) == 1
            if stationManagement.CountRRI(j) > 1
                stationManagement.CountRRI(j) = stationManagement.CountRRI(j) - 1;
            elseif stationManagement.CountRRI(j) == 1
                stationManagement.resReselectionCounterLTE(j) = stationManagement.resReselectionCounterLTE(j) - inTheLastSubframe(j);
                stationManagement.CountRRI(j) = stationManagement.RRItx(j);
            end
        end
    end
end

% fid = fopen('temp.xls','a');
% for i=1:length(resReselectionCounter)
%     fprintf(fid,'%d\t',resReselectionCounter(i));
% end
% fprintf(fid,'\n');
% fclose(fid);

% Calculate IDs of vehicles which perform reselection
scheduledID = find(stationManagement.resReselectionCounterLTE==0);

% Calculate the number of vehicles which perform reselection
Nscheduled = length(scheduledID);

% Calculate new resReselectionCounter for scheduledID
stationManagement.resReselectionCounterLTE(scheduledID) = (simParams.minRandValueMode4-1) + randi((simParams.maxRandValueMode4-simParams.minRandValueMode4)+1,1,Nscheduled);

% For those that have the counter reaching 0, a random variable should be drawn
% to define if the resource is kept or not, based on the input parameter probResKeep
if simParams.probResKeep>0
    keepRand = rand(1,Nscheduled);
    scheduledID = scheduledID(keepRand >= simParams.probResKeep);
    % Update the number of vehicles which perform reselection
    Nscheduled = length(scheduledID);
end
% else all vehicles with the counter reaching zero perform the reselection

%% Perform the reselection
for indexSensingV = 1:Nscheduled
    
    %hyeonji - step 1: selection window에서 앞으로 사용할 수 있는 candidate resource(CSRs) 파악
    
    % Select the sensing matrix only for those vehicles that perform reallocation
    % and calculate the average of the measured power over the sensing window
    %각 BRid에 해당하는 평균 sensing값 [0 0 0 ]- hj
    sensingMatrixScheduled = sum(stationManagement.sensingMatrixLTE(:,:,scheduledID(indexSensingV)),1)/length(stationManagement.sensingMatrixLTE(:,1,1));
    % "sensingMatrixScheduled" is a '1 x NbeaconIntervals' vector
        
    % Check T1 and T2 and in case set the subframes that are not acceptable to
    % infinite sensed power
    if simParams.subframeT1Mode4>1 || simParams.subframeT2Mode4<100
        if NbeaconsT~=100
            error('This part is written for NbeaconsT=100. needs revision.');
        end
        % Since the currentT can be at any point of beacon resource matrix,
        % the calculations depend on where T1 and T2 are placed
        % IF Both T1 and T2 are within this beacon period
        if (currentT+simParams.subframeT2Mode4+1)<=NbeaconsT
            sensingMatrixScheduled([1:((currentT+simParams.subframeT1Mode4-1)*NbeaconsF),((currentT+simParams.subframeT2Mode4)*NbeaconsF+1):Nbeacons]) = inf;
        % IF Both are beyond this beacon period
        elseif (currentT+simParams.subframeT1Mode4-1)>NbeaconsT
            sensingMatrixScheduled([1:((currentT+simParams.subframeT1Mode4-1-NbeaconsT)*NbeaconsF),((currentT+simParams.subframeT2Mode4-NbeaconsT)*NbeaconsF+1):Nbeacons]) = inf;
        % IF T1 within, T2 beyond
        else
            sensingMatrixScheduled(((currentT+simParams.subframeT2Mode4-NbeaconsT)*NbeaconsF+1):((currentT+simParams.subframeT1Mode4-1)*NbeaconsF)) = inf;
        end 
    end

    %hyeonji - step 2: RC=0인 CSRs가 sensing되는데, 내가 썼던 subframe에 해당하는 걸 빼고,
    %        - RSRP측정 후 threshold 넘는 걸 뺀다.
    %        - 이 때, selection window에 있는 모든 CSRs의 20% 이상을 포함하지 않는다면
    %        - RSRP threshold를 3dB씩 증가시키며 반복한다.
    
    %hyeonji - scheduledID가 사용할 BR에 해당하는 RRP 체크 값 더함 [0;0;0] -> [0 0 0]
    knownRRPMatrixScheduled = sum(stationManagement.knownRRPMatrix(:,:,scheduledID(indexSensingV)),2)';
    
    % The knownUsedMatrix of the scheduled users is obtained
%     knownUsedMatrixScheduled = stationManagement.knownUsedMatrixLTE(:,scheduledID(indexSensingV))';

    % Create random permutation of the column indexes of sensingMatrix in
    % order to avoid the ascending order on the indexes of cells with the
    % same value (sort effect) -> minimize the probability of choosing the same
    % resource
    %같은 값(정렬 효과)을 가진 셀 인덱스의 오름차순을 피하기 위해 SensingMatrix 열 인덱스의 임의 순열 생성->
    %동일한 리소스를 선택할 확률 최소화 - hj
    rpMatrix = randperm(Nbeacons);
    
    %hyeonji - 이거 왜 섞는거니?? 그 BR 쓴다는 의미를 섞어버리면 어캄?? 어차피 갯수는 같으니까 순서를 섞어서 어떤
    %정렬 효과를 줄이겠다는 것 같은데..
    knownRRPMatrixScheduledPerm = knownRRPMatrixScheduled(rpMatrix);

    % Build matrix made of random permutations of the column indexes
    % Permute sensing matrix
    sensingMatrixPerm = sensingMatrixScheduled(rpMatrix);
%     knownUsedMatrixPerm = knownUsedMatrixScheduled(rpMatrix);

    % Now perform sorting and relocation taking into account the threshold on RSRP
    % Please note that the sensed power is on a per MHz resource basis,
    % whereas simParams.powerThresholdMode4 is on a resource element (15 kHz) basis, 
    % The cycle is stopped internally; a max of 100 is used to avoid
    % infinite loops in case of bugs
    powerThreshold = simParams.powerThresholdMode4;
    while powerThreshold < 100
        % If the number of acceptable BRs is lower than MBest,
        % powerThreshold is increased by 3 dB
%         usableBRs = ((sensingMatrixPerm*0.015)<powerThreshold) | ((sensingMatrixPerm<inf) & (knownUsedMatrixPerm<1));
        %hyeonji - 내가 나를 sensing하면 inf가 되더라
        usableBRs = ((sensingMatrixPerm*0.015)<powerThreshold) | ((sensingMatrixPerm<inf) & (knownRRPMatrixScheduledPerm<1));
        if sum(usableBRs) < MBest
            powerThreshold = powerThreshold * 2;
        else
            break;
        end
    end        
    
    %hyeonji - (step 3 : RSSI 평균값들 중 가장 낮은 20% 중에서) 랜덤선택
    % To mark unacceptable RB as occupied, their power is set to Inf
    sensingMatrixPerm = sensingMatrixPerm + (1-usableBRs) * max(phyParams.P_ERP_MHz_LTE);
    
    % Sort sensingMatrix in ascending order
    [~, bestBRPerm] = sort(sensingMatrixPerm);

    % Reorder bestBRid matrix
    bestBR = rpMatrix(bestBRPerm);

    % Keep the best M canditates
    bestBR = bestBR(1:MBest);

    %hyeonji - NR SPS
%     idx = find(usableBRs == 1);
%     bestBR = rpMatrix(idx);

    % Reassign, selecting a random BR among the bestBR
    BRindex = randi(MBest);
    BR = bestBR(BRindex);

    stationManagement.BRid(scheduledID(indexSensingV))=BR;
    Nreassign = Nreassign + 1;
    
    printDebugBRofMode4(timeManagement,scheduledID(indexSensingV),BR,outParams);
end

% Reduce the knownUsedMatrix by 1 (not a problem if it goes below 0) for
% those vehicles that have checked in this subframe if it is time to change
% allocation
%할당을 변경할 때가되면 이 서브 프레임에서 체크인 한 차량에 대해 knownUsedMatrix를 1으로 줄입니다.(0 미만으로 내려 가면 문제가되지
%않음) - hj
% NOTE: the function repmat(V,n,m) creates n copies in the 1st dimension 
% and m copies in the 2nd dimension of the vector V
%repmat (V, n, m) 함수는 벡터 V의 1 차원에 n 개의 복사본을 생성하고 2 차원에 m 개의 복사본을 생성합니다. - hj
%이게뭐지?? 뭐하는 애지?? 일단 영준이는 주석처리 했었음 - hj
%repmat은 제일 앞의 벡터를 n*m만큼 복사한 것 - hj
%test = [1 2; 3 4]; repmat(test, 2,1) = [1 2;3 4;1 2;3 4]- hj
% stationManagement.knownUsedMatrixLTE = stationManagement.knownUsedMatrixLTE - repmat(inTheLastSubframe',length(stationManagement.knownUsedMatrixLTE(:,1)),1);
%length(stationManagement.knownUsedMatrixLTE(:,1)) = 100 - hj


% The channel busy ratio is calculated, if needed, every subframe for those
% nodes that have a packet generated in the subframe that just ended
if ~isempty(sinrManagement.cbrLTE)
    [timeManagement,stationManagement,sinrManagement] = cbrUpdateLTE(timeManagement,inTheLastSubframe,stationManagement,sinrManagement,appParams,simParams,phyParams,outParams);
end

end

