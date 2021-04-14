function [sinrManagement,stationManagement,timeManagement] = ...
            mainLTEsubframeStarts(appParams,phyParams,timeManagement,sinrManagement,stationManagement,simParams,simValues)
% an LTE subframe starts
        
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

% Compute the number of elapsed subframes (i.e., phyParams.Tsf)
timeManagement.elapsedTime_subframes = floor((timeManagement.timeNow+1e-9)/phyParams.Tsf) + 1;

% BR adopted in the time domain (i.e., TTI)
BRidT = ceil((stationManagement.BRid)/appParams.NbeaconsF);
BRidT(stationManagement.BRid<=0)=-1;

%hyeonji - RC값 잘 떨어지나 확인하는 용
if mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1 == 14
    hi = 2;
end

%hyeonji - Brid일 때 transmittingID 잘 건너뛰는 지 확인하는 용
if mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1 == 14
    hi = 1;
end

% Find IDs of vehicles that are currently transmitting
%stationManagement.transmittingIDsLTE = find(BRidT == (mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1));
%mainInit에서 generationPeriod에 따라서 timeNextPacket 설정해서 이대로 가도 됨 - hj


%hyeonji - transmittingID도 뛰어 넘어 보자.
%hyeonji - 매 subframe마다 transmittingID를 정할 수 있게 되어 있음
% for i = 1:simValues.maxID
%     if stationManagement.RRIcount(i) > 1
%         stationManagement.RRIcount(i) = stationManagement.RRIcount(i) - 1;
%     elseif stationManagement.RRIcount(i) == 1
%         %stationManagement.transmittingIDsLTE2 = find(BRidT(i) == (mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1));
%         if find(BRidT(i) == (mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1))
%             stationManagement.transmittingIDsLTE = i;
%         end         
%         stationManagement.RRIcount(i) = stationManagement.RRItx(i);
%     end
% end

%hyeonji - 일단 처음에 100ms까지 한 번씩은 원래대로 전송
firstadd = true;
if timeManagement.elapsedTime_subframes <= 100
    stationManagement.transmittingIDsLTE = find(BRidT == (mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1));
else %hyeonji - 100ms 이후부터는 RRI가 길면 뛰어넘기
    for i = 1:simValues.maxID
        if find(BRidT(i) == (mod((timeManagement.elapsedTime_subframes-1),appParams.NbeaconsT)+1))
            if stationManagement.RRIcount(i) > 1
                stationManagement.RRIcount(i) = stationManagement.RRIcount(i) - 1;
            elseif stationManagement.RRIcount(i) == 1
                %hyeonji - transmittingID 누적해서 추가
                if firstadd == true
                    stationManagement.transmittingIDsLTE = i;
                    firstadd = false;
                else
                    txIndex = length(stationManagement.transmittingIDsLTE);
                    stationManagement.transmittingIDsLTE(txIndex+1,1) = i;
                end
                stationManagement.RRIcount(i) = stationManagement.RRItx(i);
            end
        end
    end
end
    
    

if ~isempty(stationManagement.transmittingIDsLTE)     
    % Find index of vehicles that are currently transmitting
    stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE = zeros(length(stationManagement.transmittingIDsLTE),1);
    stationManagement.indexInActiveIDs_OfTxLTE = zeros(length(stationManagement.transmittingIDsLTE),1);
    for ix = 1:length(stationManagement.transmittingIDsLTE)
        %A = find(stationManagement.activeIDsLTE == stationManagement.transmittingIDsLTE(ix));
        %if length(A)~=1
        %    error('X');
        %end
        stationManagement.indexInActiveIDsOnlyLTE_OfTxLTE(ix) = find(stationManagement.activeIDsLTE == stationManagement.transmittingIDsLTE(ix));
        stationManagement.indexInActiveIDs_OfTxLTE(ix) = find(stationManagement.activeIDs == stationManagement.transmittingIDsLTE(ix));
    end
end

% Initialization of the received power
[sinrManagement] = initLastPowerLTE(timeManagement,stationManagement,sinrManagement,simParams,appParams,phyParams);
    