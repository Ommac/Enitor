classdef Covertype < dataset  

   
   % Define an event
   properties
        outputFormat
        classes
   end
   
   methods
        function obj = Covertype(nTr , nTe, outputFormat)

            if nTr > 522910 || nTe > 58102
                error('Too many samples required')
            end

            % Set output format
            if isempty(outputFormat)
                error('outputFormat not set');
            end
            if (strcmp(outputFormat, 'zeroOne') ||strcmp(outputFormat, 'plusMinusOne') ||strcmp(outputFormat, 'plusOneMinusBalanced'))
                obj.outputFormat = outputFormat;
            else
                display('Wrong or missing output format, set to plusMinusOne by default');
                obj.outputFormat = 'plusMinusOne';
            end            
            
            % Set t (number of classes)
            obj.t = 7;
            
            % Load data

            load covtype.data
            gnd = covtype(:,end);
            covtype(:,end) = [];
            obj.X = covtype(:,:);
            covtype = [];
            
            display('Information on the Forest Covertype dataset')
            tabulate(obj.Y)

            obj.n = size(obj.X , 1);
            obj.nTr = nTr;
            obj.nTrTot = 522910;
            obj.nTe = nTe;
            obj.nTeTot = 58102;
            obj.d = size(obj.X , 2);

            % Scale attributes
            obj.X = double(obj.X);
%             obj.X = obj.scale(obj.X);
            obj.X = obj.normalize(obj.X);

            % Set training and test indexes
            obj.trainIdx = 1:obj.nTr;
            obj.testIdx = obj.nTrTot + 1 : obj.nTrTot + obj.nTe;
            obj.shuffleTrainIdx();
            obj.shuffleTestIdx();
%             obj.shuffleAllIdx();
                
            if strcmp(obj.outputFormat, 'zeroOne')
                obj.Y = zeros(obj.n,obj.t);
            elseif strcmp(obj.outputFormat, 'plusMinusOne')
                obj.Y = -1 * ones(obj.n,obj.t);
            elseif strcmp(obj.outputFormat, 'plusOneMinusBalanced')
                obj.Y = -1/(obj.t - 1) * ones(obj.n,obj.t);
            end

            for i = 1:obj.n
                obj.Y(i , gnd(i)) = 1;
            end
               
            % Set problem type
            if obj.hasRealValues(obj.Y)
                obj.problemType = 'regression';
            else
                obj.problemType = 'classification';
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
        function perf = performanceMeasure(obj , Y , Ypred , varargin)
            Ypred = obj.scoresToClasses(Ypred);
%             RMSE
%             perf = sqrt(sum(Y - Ypred).^2)/size(Y,1));
            
            diff = Y - Ypred;
            sqDiff = diff .* diff;
            sqSumDiff = sum(sqDiff,2);
            eucNrmDiff = sqrt(sqSumDiff);
            
            perf = sqrt(sum(eucNrmDiff.^2)/size(Y,1));
            
%             Ypred = obj.scoresToClasses(Ypred);
% % 
%             % Compute error rate
%             numCorrect = 0;
%             for i = 1:size(Y,1)
%                 if sum(Y(i,:) == Ypred(i,:)) == size(Y,2)
%                     numCorrect = numCorrect +1;
%                 end
%             end
% 
%             perf = 1 - (numCorrect / size(Y,1));     

%                 C = transpose(bsxfun(@eq, Y', Ypred'));
%                 D = sum(C,2);
%                 E = D == size(Y,2);
%                 numCorrect = sum(E);
%                 perf = 1 - (numCorrect / size(Y,1));    
        end
        
        % Scales matrix M between 0 and 1
        function Ms = scale(obj , M)

            mx = max(M);
            mn = min(M);
            
            delta = mx - mn;
            Ms = transpose(bsxfun(@minus, M', mn'));
            Ms = transpose(bsxfun(@rdivide, Ms', delta'));
        end  
        
        % Normalizes and centers the columns of M
        function Ms = normalize(obj , M)

            me = mean(M);
                        
            Ms = transpose(bsxfun(@minus, M', me'));
            
            sd = std(Ms,1);
            
            Ms = transpose(bsxfun(@rdivide, M', sd'));
            
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
    end % methods
end % classdef
