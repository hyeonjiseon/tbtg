function distanceDetailsCounter = countDistanceDetails(indexVehicleTX,neighborsID,neighborsDistance,errorMatrix,distanceDetailsCounter,outParams,positionManagement,stationManagement)
% Count events for distances up to the maximum awareness range (removing border effect)
% [distance, #Correctly received beacons, #Errors, #Blocked neighbors, #Neighbors]
% #Neighbors will be calculated in "printDistanceDetailsCounter.m" (only one call)

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

% Update array with the events vs. distance
for i = 1:1:length(distanceDetailsCounter(:,1))
    %LTEV2Vsim.m 185-191 line에서 outputValues.distanceDetailsCounterLTE =
    %zeros(floor(phyParams.RawMaxLTE/outParams.prrResolution),5);로 초기화됨 - hj
    %RawMaxLTE가 439.9420으로 되어 있어서 10으로 나누고 floor하면 43이 된다. - hj
    %그래서 43*5 metrix가 됨 - hj
    
    distance = i * outParams.prrResolution;
          
    % Number of receiving neighbors at i meters
    %transmittingID의 neighbors면서 그 거리가 설정된 distance보다 작은 것의 갯수 - hj
    NrxNeighbors = nnz((neighborsID(indexVehicleTX,:)>0).*(neighborsDistance(indexVehicleTX,:) < distance));
    
    %hyeonji - edge effect를 낼 수 있는 차량을 제외시켜야 할 것 같음 
%     edgeMetrix = zeros(length(indexVehicleTX), length(stationManagement.activeIDsLTE)-1);
%     edgeMetrix = positionManagement.XvehicleReal(indexVehicleTX,neighborsID(indexVehicleTX,:));
%     NrxNeighbors = nnz((neighborsID(indexVehicleTX,:)>0).* (neighborsDistance(indexVehicleTX,:) < distance) ...
%         .* ((positionManagement.XvehicleReal(neighborsID(indexVehicleTX,:) > 0) > 1000) | (positionManagement.XvehicleReal(neighborsID(indexVehicleTX,:) > 0) < 2000)));
    
%     edgeError1 = 0;
%     edgeError2 = 0;
% 
%     for j = 1:length(indexVehicleTX)
%         for k = 1:length(neighborsID(indexVehicleTX(j),:))
%              if (neighborsID(indexVehicleTX(j),k) > 0) && (neighborsDistance(indexVehicleTX(j),k) < distance) && ((positionManagement.XvehicleReal(neighborsID(indexVehicleTX(j),k)) < 1000)...
%                      || (positionManagement.XvehicleReal(neighborsID(indexVehicleTX(j),k)) > 2000))
%                  edgeError1 = edgeError1 + 1;
%              end
%         end
%     end
%     
%     NrxNeighbors = NrxNeighbors - edgeError1;
                 
    
    % #Errors within i meters
    Nerrors = nnz(errorMatrix(:,4) < distance);
    
    %hyeonji - 여기서도 edge effect를 낼 수 있는 차량 제외하기
%     Nerrors = nnz((errorMatrix(:,4) < distance) .* ((positionManagement.XvehicleReal(errorMatrix(:,2)) < 1000) | (positionManagement.XvehicleReal(errorMatrix(:,2)) > 2000)));
    
%     Nerrors = 0;
%     for m = 1: length(errorMatrix)
%         if ismember(errorMatrix(m,1),indexVehicleTX)
%             if errorMatrix(m,4) < distance
%                 Nerrors = Nerrors + 1;
%             end
%             if (errorMatrix(m,4) < distance) && ((positionManagement.XvehicleReal(errorMatrix(m,2)) < 1000) || (positionManagement.XvehicleReal(errorMatrix(m,2)) > 2000))
%                 edgeError2 = edgeError2 + 1;
%             end
%         end        
%     end
%     
%     Nerrors = Nerrors - edgeError2;
    
    distanceDetailsCounter(i,3) = distanceDetailsCounter(i,3) + Nerrors;
    
    % #Correctly received beacons within i meters
    NrxOK = NrxNeighbors - Nerrors;
    distanceDetailsCounter(i,2) = distanceDetailsCounter(i,2) + NrxOK;
    
end

end
