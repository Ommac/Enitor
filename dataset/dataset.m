
classdef dataset < handle
   
   properties
       
        problemType     % regression or classification
        
        n
        nTr
        nTe
        
        nTot
        nTrTot
        nTeTot
        d
        t

        X
        Y

        trainIdx
        testIdx
        %shuffledTrainIdx
   end
   
   methods
        
        function obj = dataset(fname)
            if  nargin > 0            
                data = load(fname);
                obj.X = data.X;
                obj.Y = data.Y;
                obj.n = size(data.X , 1);
                obj.d = size(data.X , 2);
                obj.t = size(data.y , 2);
                
                % Set problem type

                obj.problemType = 'classification';
                for i = 1:size(obj.Y,1)
                    for j = 1:size(obj.Y,2)

                        if mod(obj.Y(i,j),1) ~= 0
                            obj.problemType = 'regression';
                        end
                    end
                end
            end
        end       

        
        % Compute random permutation of the training set indexes
        function shuffleTrainIdx(obj)
            obj.trainIdx = obj.trainIdx(randperm(obj.nTr));
        end
        
        % Compute random permutation of the test set indexes
        function shuffleTestIdx(obj)
            obj.testIdx = obj.testIdx(randperm(obj.nTe));
        end
        
        % Compute random permutation of the test set indexes
        function shuffleAllIdx(obj)
            tmp = [obj.trainIdx obj.testIdx];
            tmp2 = tmp(randperm(obj.nTr+obj.nTe));
            obj.trainIdx = tmp2(1:obj.nTr);
            obj.testIdx = tmp2(obj.nTrTot+1:obj.nTrTot+obj.nTe);
        end
    end % methods
end % classdef