function generationInterval = generationPeriodFromSpeed(speed,appParams)

speedKmh = speed*3.6; %speed는 m/s라서 3.6을 곱하면 km/h로 변함 - hj
N = speedKmh/10;

CPeriod = (1.440)./N; %rufrnr 4/v와 같아짐 - hj

switch appParams.camDiscretizationType
    
    case 'allSteps'
        Possible=0.1:0.1:1; %0.1부터 1까지 0.1간격, [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1] - hj
    case 'allocationAligned'
        Possible=[0.1,0.2,0.5,1];
end

generationInterval=CPeriod;

if ~strcmp(appParams.camDiscretizationType, 'null')    
	Paugmented=CPeriod.*(1+appParams.camDiscretizationIncrease./100);
    for pp=1:length(Paugmented)
        [~,j]=min(abs(Paugmented(pp)-Possible));
        generationInterval(pp)=Possible(j).*(Possible(j)<=Paugmented(pp))+Possible(max(j-1,1)).*(Possible(j)>Paugmented(pp));
    end
end

generationInterval = max(min(generationInterval,1),0.1);

% Survey on ITS-G5 CAM statistics
% CAR 2 CAR Communication Consortium
%
% speedKmh beacon // period in ms
% 20                 720
% 40                 360
%
% 720*2:1440/2 -- 360*4: 1440/4
% period is 1440/N, where speed is 10*N
%
% MIN is 1 Hz at 14.4 km/h
% MAX is 10 Hz at 144 km/h