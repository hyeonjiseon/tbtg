function generationInterval = generationPeriodFromSpeed(speed,appParams)

speedKmh = speed*3.6; %speed는 m/s라서 3.6을 곱하면 km/h로 변함 - hj
N = speedKmh/10;

CPeriod = (1.440)./N; %rufrnr 4/v와 같아짐 - hj

switch appParams.camDiscretizationType
    
    case 'allSteps'
        Possible=0.1:0.1:1; %0.1부터 1까지 0.1간격, [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1] - hj
        %임의로 allSteps로 했더니 0.72가 나와야 할 상황에 0.8로 결과가 나오게 됨 - hj
    case 'allocationAligned'
        Possible=[0.1,0.2,0.5,1];
        %임의로 allocationAligned로 설정했더니 0.72가 나와야 할 상황에 0.5로 결과가 나오게 됨 - hj
end %이것들은 generation period를 속도가 적게 변할 땐 어느 정도 일정하게 유지시키려는 의도로 짜여진 코드인 것 같다 - hj

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