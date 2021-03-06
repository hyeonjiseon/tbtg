function [simValues,outputValues,appParams,simParams,phyParams,sinrManagement,outParams,stationManagement] = mainV2X(appParams,simParams,phyParams,outParams,simValues,outputValues,positionManagement)
% Core function where events are sorted and executed

%% Initialization
[appParams,simParams,phyParams,outParams,simValues,outputValues,...
    sinrManagement,timeManagement,positionManagement,stationManagement] = mainInit(appParams,simParams,phyParams,outParams,simValues,outputValues,positionManagement);

% The simulation starts at time '0'
timeManagement.timeNow = 0;

% The variable 'timeNextPrint' is used only for printing purposes
timeNextPrint = 0;

% The variable minNextSuperframe is used in the case of coexistence
minNextSuperframe = min(timeManagement.coex_timeNextSuperframe);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Simulation Cycle
% The simulation ends when the time exceeds the duration of the simulation
% (not really used, since a break inside the cycle will stop the simulation
% earlier)

% Start stopwatch
tic

fprintf('Simulation Time: ');
reverseStr = '';

while timeManagement.timeNow < simParams.simulationTime

    % The instant and node of the next event is obtained
    % indexEvent is the index of the vector IDvehicle
    % idEvent is the ID of the vehicle of the current event
    [timeEvent, indexEvent] = min(timeManagement.timeNextEvent(stationManagement.activeIDs));
    %timeNextEvent는 mainInit에서 timeNextPacket과 같은 값이라고 정해짐 - hj
    %timeNextPacket에서 가장 작은 값 timeEvent로, 그 index를 indexEvent 뽑아냄 - hj
    idEvent = stationManagement.activeIDs(indexEvent);

    % If the next LTE event is earlier than timeEvent, set the time to the
    % LTE event
    if timeEvent >= timeManagement.timeNextLTE %mainInit에서 LTE가 시작될 예정이라면 0에서 첫 번재 subframe 시작하므로 0으로 초기화
        timeEvent = timeManagement.timeNextLTE; %맨 처음엔 0
        %fprintf('LTE subframe %.6f\n',timeEvent);
    end

    % If the next superframe event (coexistence, method A) is earlier than timeEvent, set the time to the
    % this event
    if timeEvent >= minNextSuperframe
        timeEvent = minNextSuperframe;
    end
        
   % If timeEvent is later than the next CBR update, set the time
    % to the CBR update
    if timeEvent >= (timeManagement.timeNextCBRupdate-1e-12)
        timeEvent = timeManagement.timeNextCBRupdate;
        %fprintf('CBR update%.6f\n',timeEvent);
    end
        
    % If timeEvent is later than the next position update, set the time
    % to the position update
    % With LTE, it must necessarily be done after the end of a subframe and
    % before the next one
    if timeEvent >= (timeManagement.timeNextPosUpdate-1e-9) && ...
        (isempty(stationManagement.activeIDsLTE) || timeEvent > timeManagement.timeNextLTE || timeManagement.subframeLTEstarts==true)
    %timeNextPosUpdate는 mainInit에서 positionTimeResolution 값과 같게 초기화 한다 - hj
    %positionTimeResolution은 trace file에서 positioning update하는 time resolution으로, 0.1초(100ms)가 기본이다. - hj
        timeEvent = timeManagement.timeNextPosUpdate;
        % It might happen that the time in timeManagement.timeNextPosUpdate
        % is before time now - time now should not go back
        timeManagement.timeNow = max(timeEvent,timeManagement.timeNow);
    else
        % The time instant is updated
        timeManagement.timeNow = timeEvent;
    end
    
    % If the time instant exceeds or is equal to the duration of the
    % simulation, the simulation is ended
    if round(timeManagement.timeNow*1e10)/1e10>=round(simParams.simulationTime*1e10)/1e10
        break;
    end

    %%
    % Print time to video
    while timeManagement.timeNow>timeNextPrint
        reverseStr = printUpdateToVideo(timeManagement.timeNow,simParams.simulationTime,reverseStr);
        timeNextPrint = timeNextPrint + simParams.positionTimeResolution;
    end
    %%
    
    %% Action
    % The action at timeManagement.timeNow depends on the selected event
 
    % POSITION UPDATE: positions of vehicles are updated
    if timeEvent==timeManagement.timeNextPosUpdate        
        % DEBUG EVENTS
        %printDebugEvents(timeEvent,'position update',-1);
        
        if isfield(timeManagement,'subframeLTEstarts') && timeManagement.subframeLTEstarts==false
            % During a position update, some vehicles can enter or exit the
            % scenario; this is not managed if it happens during one
            % subframe
            error('A position update is occurring during the subframe; not allowed by implementation.');
        end
            
        [appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement] = ...
              mainPositionUpdate(appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement);
        
        % DEBUG IMAGE
        % printDebugImage('position update',timeManagement,stationManagement,positionManagement,simParams,simValues);

        % Set value of next position update
        timeManagement.timeNextPosUpdate = timeManagement.timeNextPosUpdate + simParams.positionTimeResolution;
        positionManagement.NposUpdates = positionManagement.NposUpdates+1;

    elseif timeEvent == timeManagement.timeNextCBRupdate
        % Part dealing with the channel busy ratio calculation
        % Done for every station in the system, if the option is active
        %
        thisSubInterval = mod(ceil((timeEvent-1e-9)/(simParams.cbrSensingInterval/simParams.cbrSensingIntervalDesynchN))-1,simParams.cbrSensingIntervalDesynchN)+1;
        %
        % ITS-G5
        % CBR and DCC (if active)
        if ~isempty(stationManagement.activeIDs11p)
            vehiclesToConsider = stationManagement.activeIDs11p(stationManagement.cbr_subinterval(stationManagement.activeIDs11p)==thisSubInterval);        
            [timeManagement,stationManagement,stationManagement.cbr11pValues(vehiclesToConsider,ceil(timeEvent/simParams.cbrSensingInterval))] = ...
                cbrUpdate11p(timeManagement,vehiclesToConsider,stationManagement,simParams,phyParams);
        end
        % In case of Mitigation method with dynamic slots, also in LTE nodes
        if simParams.technology==4 && simParams.coexMethod>0 && simParams.coex_slotManagement==2 && simParams.coex_cbrTotVariant==2
            vehiclesToConsider = stationManagement.activeIDsLTE(stationManagement.cbr_subinterval(stationManagement.activeIDsLTE)==thisSubInterval);
            [timeManagement,stationManagement,sinrManagement.cbrLTE_coex11ponly(vehiclesToConsider)] = ...
                cbrUpdate11p(timeManagement,vehiclesToConsider,stationManagement,simParams,phyParams);
        end
        
        % LTE-V2X
        % CBR and DCC (if active)
        if ~isempty(stationManagement.activeIDsLTE)
            vehiclesToConsider = stationManagement.activeIDsLTE(stationManagement.cbr_subinterval(stationManagement.activeIDsLTE)==thisSubInterval);
            [timeManagement,stationManagement,sinrManagement,stationManagement.cbrLteValues(vehiclesToConsider,ceil(timeEvent/simParams.cbrSensingInterval)),stationManagement.coex_cbrLteOnlyValues(vehiclesToConsider,ceil(timeEvent/simParams.cbrSensingInterval))] = ...
                cbrUpdateLTE(timeManagement,vehiclesToConsider,stationManagement,sinrManagement,appParams,simParams,phyParams,outParams);
        end
        
        %
        timeManagement.timeNextCBRupdate = timeManagement.timeNextCBRupdate + (simParams.cbrSensingInterval/simParams.cbrSensingIntervalDesynchN);

    elseif timeEvent == minNextSuperframe
        % only possible in coexistence with mitigation methods
        if simParams.technology~=4 || simParams.coexMethod==0
            error('Superframe is only possible with coexistence, Methods A, B, C, F');
        end
        
        % coexistence Methods, superframe boundary
        [timeManagement,stationManagement,sinrManagement,outputValues] = ...
            superframeManagement(timeManagement,stationManagement,simParams,sinrManagement,phyParams,outParams,simValues,outputValues);
                    
        minNextSuperframe=min(timeManagement.coex_timeNextSuperframe(stationManagement.activeIDs));
        
        % CASE LTE
    elseif timeEvent == timeManagement.timeNextLTE

        if timeManagement.subframeLTEstarts
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'LTE subframe starts',-1);
            %fprintf('Starts\n');
            
            [sinrManagement,stationManagement,timeManagement,outputValues] = ...
                mainLTEsubframeStarts(appParams,phyParams,timeManagement,sinrManagement,stationManagement,simParams,simValues,outParams,outputValues);

            % DEBUG TX-RX
            %if isfield(stationManagement,'IDvehicleTXLTE') && ~isempty(stationManagement.transmittingIDsLTE)
            %    printDebugTxRx(timeManagement.timeNow,'LTE subframe starts',stationManagement,sinrManagement);
            %end

            % DEBUG TX
            printDebugTx(timeManagement.timeNow,true,-1,stationManagement,positionManagement,sinrManagement,outParams,phyParams);

            timeManagement.subframeLTEstarts = false;
            timeManagement.timeNextLTE = timeManagement.timeNextLTE + (phyParams.Tsf - phyParams.TsfGap);

            % DEBUG IMAGE
            %if isfield(stationManagement,'IDvehicleTXLTE') && ~isempty(stationManagement.transmittingIDsLTE)
            %    printDebugImage('LTE subframe starts',timeManagement,stationManagement,positionManagement,simParams,simValues);
            %end
        else
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'LTE subframe ends',-1);
            %fprintf('Stops\n');

            [phyParams,simValues,outputValues,sinrManagement,stationManagement,timeManagement] = ...
                mainLTEsubframeEnds(appParams,simParams,phyParams,outParams,simValues,outputValues,timeManagement,positionManagement,sinrManagement,stationManagement);

            % DEBUG TX-RX
            %if isfield(stationManagement,'IDvehicleTXLTE') && ~isempty(stationManagement.transmittingIDsLTE)
            %    printDebugTxRx(timeManagement.timeNow,'LTE subframe ends',stationManagement,sinrManagement);
            %end

            timeManagement.subframeLTEstarts = true;
            timeManagement.timeNextLTE = timeManagement.timeNextLTE + phyParams.TsfGap;

            % DEBUG IMAGE
            %if isfield(stationManagement,'IDvehicleTXLTE') && ~isempty(stationManagement.transmittingIDsLTE)
            %    printDebugImage('LTE subframe ends',timeManagement,stationManagement,positionManagement,simParams,simValues);
            %end
        end
     
    % CASE A: new packet is generated
    elseif timeEvent == timeManagement.timeNextPacket(idEvent)
        
        printDebugReallocation(timeEvent,idEvent,positionManagement.XvehicleReal(indexEvent),'gen',-1,outParams);

        if stationManagement.vehicleState(idEvent)==100 % is LTE
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'New packet, LTE',idEvent);

            stationManagement.pckBuffer(idEvent) = stationManagement.pckBuffer(idEvent)+1;
            if stationManagement.pckBuffer(idEvent)>1
                [stationManagement,outputValues] = bufferOverflowLTE(idEvent,positionManagement,stationManagement,phyParams,outputValues,outParams);
            end            
            
            % DEBUG IMAGE
            %printDebugImage('New packet LTE',timeManagement,stationManagement,positionManagement,simParams,simValues);
        else % is not LTE
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'New packet, 11p',idEvent);
            
            % In the case of 11p, some processing is necessary
            [timeManagement,stationManagement,outputValues] = ...
                newPacketIn11p(timeEvent,idEvent,indexEvent,outParams,simParams,positionManagement,phyParams,timeManagement,stationManagement,sinrManagement,outputValues,appParams);
   
            % DEBUG TX-RX
            %printDebugTxRx(timeManagement.timeNow,'11p tx started',stationManagement,sinrManagement);
            printDebugBackoff11p(timeManagement.timeNow,'11p backoff started',idEvent,stationManagement,outParams)

            % DEBUG IMAGE
            %printDebugImage('New packet 11p',timeManagement,stationManagement,positionManagement,simParams,simValues);
        end

        printDebugGeneration(timeManagement,idEvent,positionManagement,outParams);
        
        timeManagement.timeNextPacket(idEvent) = timeManagement.timeNow + max(timeManagement.generationInterval(idEvent),timeManagement.dcc_minInterval(idEvent));
        %현재시간에 genreationInterval을 더해서 또 이 시간이 되었을 때 패킷을 생성 - hj
        timeManagement.timeLastPacket(idEvent) = timeManagement.timeNow-timeManagement.addedToGenerationTime(idEvent);
        
        if simParams.technology==4 && simParams.coexMethod==1 && simParams.coexA_improvements>0
            timeManagement = coexistenceImprovements(timeManagement,idEvent,stationManagement,simParams,phyParams);
        end                
         
        % CASE B+C: either a backoff or a transmission concludes
    else % txrxevent-11p
        % A backoff ends
        if stationManagement.vehicleState(idEvent)==2 % END backoff
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'backoff concluded, tx start',idEvent);
            
            [timeManagement,stationManagement,sinrManagement,outputValues] = ...
                endOfBackoff11p(idEvent,indexEvent,simParams,simValues,phyParams,timeManagement,stationManagement,sinrManagement,appParams,outParams,outputValues);
 
            % DEBUG TX-RX
            %printDebugTxRx(timeManagement.timeNow,'11p tx started',stationManagement,sinrManagement);
            printDebugBackoff11p(timeManagement.timeNow,'11p tx started',idEvent,stationManagement,outParams)
 
            % DEBUG TX
            printDebugTx(timeManagement.timeNow,true,idEvent,stationManagement,positionManagement,sinrManagement,outParams,phyParams);
            
            % DEBUG IMAGE
            %printDebugImage('11p TX starts',timeManagement,stationManagement,positionManagement,simParams,simValues);
 
            % A transmission ends
        elseif stationManagement.vehicleState(idEvent)==3 % END tx
            % DEBUG EVENTS
            %printDebugEvents(timeEvent,'Tx concluded',idEvent);
            
            [simValues,outputValues,timeManagement,stationManagement,sinrManagement] = ...
                endOfTransmission11p(idEvent,indexEvent,positionManagement,phyParams,outParams,simParams,simValues,outputValues,timeManagement,stationManagement,sinrManagement,appParams);
            
            % DEBUG IMAGE
            %printDebugImage('11p TX ends',timeManagement,stationManagement,positionManagement,simParams,simValues);

            % DEBUG TX-RX
            %printDebugTxRx(timeManagement.timeNow,'11p tx ended',stationManagement,sinrManagement);
            printDebugBackoff11p(timeManagement.timeNow,'11p tx ended',idEvent,stationManagement,outParams)

        else
            fprintf('idEvent=%d, state=%d\n',idEvent,stationManagement.vehicleState(idEvent));
            error('Ends unknown event...')
        end
    end
    
    % The next event is selected as the minimum of all values in 'timeNextPacket'
    % and 'timeNextTxRx'
    timeManagement.timeNextEvent = min(timeManagement.timeNextPacket,timeManagement.timeNextTxRx11p);
    if min(timeManagement.timeNextEvent(stationManagement.activeIDs)) < timeManagement.timeNow-1e-8 % error check
        format long
        fprintf('next=%f, now=%f\n',min(timeManagement.timeNextEvent(stationManagement.activeIDs)),timeManagement.timeNow);
        error('An event is schedule in the past...');
    end
    
end

% Print end of simulation
msg = sprintf('%.1f / %.1fs',simParams.simulationTime,simParams.simulationTime);
fprintf([reverseStr, msg]);

% Number of position updates
simValues.snapshots = positionManagement.NposUpdates;

% Stop stopwatch
outputValues.computationTime = toc;

end
