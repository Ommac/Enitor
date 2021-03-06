% round digits (3, 6, 8, 9, 0) 
% versus non-round digits (1, 2, 4, 5, 7)
classdef mnist_b < dataset
   
   properties
        outputFormat
   end
   
   methods
        function obj = mnist_b(nTr , nTe, outputFormat , shuffleTrain , shuffleTest)
            
            data = load('mnist_all.mat');
            
            gnd = [];
            
            for i = 0:9
                currentFieldStr = strcat('train' , num2str(i));
                obj.X = [ obj.X ; data.(currentFieldStr) ];
                gnd = [gnd ; i * ones(size(data.(currentFieldStr),1) , 1) ];
            end
                
            obj.nTr = size(obj.X,1);
            obj.nTrTot = obj.nTr;
            
            for i = 0:9
                currentFieldStr = strcat('test' , num2str(i));
                obj.X = [ obj.X ; data.(currentFieldStr) ];
                gnd = [gnd ; i * ones(size(data.(currentFieldStr),1) , 1) ];
            end
            
            obj.X = double(obj.X);
            obj.X = obj.scale(obj.X , 0 , 1);
            
            obj.n = size(obj.X , 1);
            obj.nTe = obj.n - obj.nTr;
            obj.nTeTot = obj.nTe;
            
            obj.d = size(obj.X , 2);
            obj.t = 1;
                
            if nargin == 0

                obj.trainIdx = 1:obj.nTr;
                obj.testIdx = obj.nTr + 1 : obj.nTr + obj.nTe;
                
            elseif (nargin >1)
                
                if (nTr < 2) || (nTe < 1) ||(nTr > obj.nTrTot) || (nTe > obj.nTeTot)
                    error('(nTr > obj.nTrTot) || (nTe > obj.nTeTot)');
                end
                
                obj.nTr = nTr;
                obj.nTe = nTe;
                
                tmp = randperm( obj.nTrTot);                            
                obj.trainIdx = tmp(1:obj.nTr);          
                
                tmp = obj.nTrTot + randperm( obj.nTeTot );
                obj.testIdx = tmp(1:obj.nTe);
            end
            
            if shuffleTrain == 1
                obj.shuffleTrainIdx();
            end
            if shuffleTest == 1
                obj.shuffleTestIdx();
            end
            
            % Reformat output columns
            if (nargin > 2) && (strcmp(outputFormat, 'zeroOne') ||strcmp(outputFormat, 'plusMinusOne') ||strcmp(outputFormat, 'plusOneMinusBalanced'))
                obj.outputFormat = outputFormat;
            else
                display('Wrong or missing output format, set to plusMinusOne by default');
                obj.outputFormat = 'plusMinusOne';
            end
            
            if strcmp(obj.outputFormat, 'zeroOne')
                obj.Y = zeros(obj.n,obj.t);
            elseif strcmp(obj.outputFormat, 'plusMinusOne')
                obj.Y = -1 * ones(obj.n,obj.t);
            elseif strcmp(obj.outputFormat, 'plusOneMinusBalanced')
                obj.Y = -1/(obj.t - 1) * ones(obj.n,obj.t);
            end
            
            % Group digits as follows:
            % round digits (3, 6, 8, 9, 0) 
            % versus non-round digits (1, 2, 4, 5, 7)
            for i = 1:obj.n
                if gnd(i) == 1 || gnd(i) == 2 || gnd(i) == 4 || gnd(i) == 5 || gnd(i) == 7
                    obj.Y(i) = 1;
                end
            end
            
            % Set problem type
%             if obj.hasRealValues(obj.Y)
%                 obj.problemType = 'regression';
%             else
                obj.problemType = 'classification';
%             endr
        end
        
        % Checks if matrix Y contains real values. Useful for
        % discriminating between classification and regression, or between
        % predicted scores and classes
        function res = hasRealValues(obj , M)
        
            res = false;
            for i = 1:size(M,1)
                for j = 1:size(M,2)
                    if mod(M(i,j),1) ~= 0
                        res = true;
                    end
                end
            end
        end
        
        % Compute predictions matrix from real-valued scores matrix
        function Ypred = scoresToClasses(obj , Yscores)    
            
            if strcmp(obj.outputFormat, 'zeroOne')
                Ypred = zeros(size(Yscores));
            elseif strcmp(obj.outputFormat, 'plusMinusOne')
                Ypred = -1 * ones(size(Yscores));
            elseif strcmp(obj.outputFormat, 'plusOneMinusBalanced')
                Ypred = -1/(obj.t - 1) * ones(size(Yscores));
            end
            
            for i = 1:size(Ypred,1)
                [~,maxIdx] = max(Yscores(i,:));
                Ypred(i,maxIdx) = 1;
            end
        end
            
        % Compute performance measure on the given outputs according to the
        % USPS dataset-specific ranking standard measure
        function perf = performanceMeasure(obj , Y , Ypred , varargin)
            
            % Check if Ypred is real-valued. If yes, convert it.
            if obj.hasRealValues(Ypred)
                Ypred = obj.scoresToClasses(Ypred);
            end
            
            % Compute error rate
            numCorrect = 0;
            
            for i = 1:size(Y,1)
                if sum(Y(i,:) == Ypred(i,:)) == size(Y,2)
                    numCorrect = numCorrect +1;
                end
            end
            
            perf = 1 - (numCorrect / size(Y,1));
        end
        
        % Scales matrix M between -1 and 1
        function Ms = scale(obj , M , lowLim , highLim)
            
            mx = max(max(M));
            mn = min(min(M));
            
            Ms = ((M + abs(mn)) / (mx - mn)) * (highLim - lowLim) + lowLim;
            
        end
        
        function getTrainSet(obj)
            
        end
        
        function getTestSet(obj)
            
        end
        
   end % methods
end % classdef