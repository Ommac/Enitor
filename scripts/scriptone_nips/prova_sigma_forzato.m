setenv('LC_ALL','C');
% addpath(genpath('.'));
% addpath(genpath('/home/iit.local/rcamoriano/repos/Enitor'));
 
clearAllButBP;
% close all;

% Set experimental results relative directory name
resdir = '';
mkdir(resdir);

%% Initialization

storeFullTrainPerf = 0;
storeFullValPerf = 1;
storeFullTestPerf = 0;
verbose = 0;
saveResult = 0;

% Load dataset

perfVec  = [];
numRep = 10;

for i = 1:numRep
    
    ds = cpuSmall(6554,1638);    
%     ds = breastCancer(400,169,'zeroOne');    
%     ds = Adult(32000,16282,'zeroOne');    

    for sigma = 0.1

        %% Batch Nystrom KRLS

        map = @nystromUniform;
        filter = @tikhonov;
        numNysParGuesses = 20;
        mapParGuesses = sigma;
        filterParGuesses = 1e-12;

        alg = nrls(map , filter , 5000 , ...
                                'numNysParGuesses', numNysParGuesses , ...
                                'mapParGuesses' , mapParGuesses ,  ... 
                                'filterParGuesses', filterParGuesses , ...
                                'verbose' , 0 , ...
                                'storeFullTrainPerf' , storeFullTrainPerf , ...
                                'storeFullValPerf' , storeFullValPerf , ...
                                'storeFullTestPerf' , storeFullTestPerf );

    %     alg.mapParStar = [ 0 , 5.7552];
    %     alg.filterParStar = 1e-9;

    %     tic
    %     alg.justTrain(ds.X(ds.trainIdx,:) , ds.Y(ds.trainIdx));
    %     trTime = toc;
    %     
    %     YtePred = alg.test(ds.X(ds.testIdx,:));   
    %       
    %     perf = abs(ds.performanceMeasure( ds.Y(ds.testIdx,:) , YtePred , ds.testIdx));
    %     nysTrainTime = [nysTrainTime ; trTime];
    %     nysTestPerformance = [nysTestPerformance ; perf'];

        expNysBat = experiment(alg , ds , 1 , true , saveResult , '' , resdir , 0);
        expNysBat.run();
    %     expNysBat.result


    end
    perfVec = [perfVec ; expNysBat.algo.valPerformance'];

end

%%
figure
% area(perfVec)
boxplot(perfVec , 'plotstyle' , 'compact')