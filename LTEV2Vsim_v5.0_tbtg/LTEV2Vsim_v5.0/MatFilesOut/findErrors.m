function errorMatrix = findErrors(IDvehicleTXLTE,indexVehicleTX,neighborsID,sinrManagement,stationManagement,positionManagement,phyParams)
% Detect wrongly decoded beacons and create Error Matrix
% [ID TX, ID RX, BRid, distance]

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

distance = positionManagement.distanceReal(stationManagement.vehicleState(stationManagement.activeIDs)==100,stationManagement.vehicleState(stationManagement.activeIDs)==100);

Ntx = length(IDvehicleTXLTE);              % Number of tx vehicles
errorMatrix = zeros(Ntx*Ntx-1,4);          % Initialize error matrix
Nerrors = 0;                               % Initialize number of errors

%hyeonji - 잘 된 것 찾기
% correctMatrix = zeros(Ntx*Ntx-1,4);
% Ncorrects = 0;

for i = 1:Ntx

    % Find indexes of receiving vehicles in neighborsID
    indexNeighborsRX = find(neighborsID(indexVehicleTX(i),:));

    for j = 1:length(indexNeighborsRX)
        % If received beacon SINR is lower than the threshold
        %if sinrManagement.neighborsSINR(i,indexNeighborsRX(j)) < phyParams.gammaMinLTE
        % randomSINRthreshold = sinrV(randi(length(sinrV)))
        if sinrManagement.neighborsSINRaverageLTE(i,indexNeighborsRX(j)) < phyParams.sinrVectorLTE(randi(length(phyParams.sinrVectorLTE)))
            %아예 받지 못해서 0이어도 threshold보다 낮은 건 맞으니까 들어가게 됨 - hj        
        
            IDvehicleRX = neighborsID(indexVehicleTX(i),indexNeighborsRX(j));
            Nerrors = Nerrors + 1;
            errorMatrix(Nerrors,1) = IDvehicleTXLTE(i);
            errorMatrix(Nerrors,2) = IDvehicleRX;
            errorMatrix(Nerrors,3) = stationManagement.BRid(IDvehicleTXLTE(i));
            errorMatrix(Nerrors,4) = distance(indexVehicleTX(i),stationManagement.activeIDsLTE==IDvehicleRX);
%                 fid = fopen('temp.xls','a');
%                 fprintf(fid,'%d\t%d\t%.3f\t%f\t%f\t%f\n',IDvehicleRX,IDvehicleTX(i),distance(indexVehicleTX(i),IDvehicle==IDvehicleRX),...
%                     sinrManagement.neighPowerUsefulLastLTE(i,indexNeighborsRX(j)), sinrManagement.neighPowerInterfLastLTE(i,indexNeighborsRX(j)),neighborsSINRaverageLTE(i,indexNeighborsRX(j)));
%                 fclose(fid);
%         else % hyeonji - 잘된 것 찾기 1.3546보다 크면 다 여기
%             cIDvehicleRX = neighborsID(indexVehicleTX(i),indexNeighborsRX(j));
%             Ncorrects = Ncorrects + 1;
%             correctMatrix(Ncorrects,1) = IDvehicleTXLTE(i);
%             correctMatrix(Ncorrects,2) = cIDvehicleRX;
%             correctMatrix(Ncorrects,3) = stationManagement.BRid(IDvehicleTXLTE(i));
%             correctMatrix(Ncorrects,4) = distance(indexVehicleTX(i),stationManagement.activeIDsLTE==cIDvehicleRX);
            
        end
    end
end

delIndex = errorMatrix(:,1)==0;
errorMatrix(delIndex,:) = [];

% hyeonji - 잘된 것 찾기
% delIndex2 = correctMatrix(:,1)==0;
% correctMatrix(delIndex2,:) = [];

end
