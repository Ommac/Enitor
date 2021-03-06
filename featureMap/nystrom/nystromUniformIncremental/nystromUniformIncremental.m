classdef nystromUniformIncremental < nystrom
    %NYSTROMUNIFORM Implementation of an integrated incremental Nystrom low-rank
    %approximator/regularizer and Tikhonov regularizer.
    %
    % Input parameters:
    % TO DO.

    
    properties
        numMapParRangeSamples   % Number of samples of X considered for estimating the maximum and minimum sigmas
        minRank                 % Minimum rank of the kernel approximation
        maxRank                 % Maximum rank of the kernnystromUniformIncrementalel approximation
        
        filterPar               % Filter parameter (lambda)
        
        mapParGuesses           % mapping parameter guesses
        numMapParGuesses        % Number of mapping parameter guesses
        
        kernelType      % Type of approximated kernel
        SqDistMat       % Squared distances matrix
        Xs              % Sampled points
        Y               % Training outputs
        
        s               % Number of new columns
        ntr             % Total number of training samples
        t
        
        prevPar
        
        % Variables for computeSqDistMat efficiency
        X1
        X2
        Sx1
        Sx2
        
        A
        Aty
        R
        alpha
    end
    
    methods
        
        function obj = nystromUniformIncremental( X , Y , ntr , varargin)
            obj.init( X , Y , ntr , varargin);
        end

        function obj = init(obj , X , Y , ntr , varargin)
            
            p = inputParser;
            
            %%%% Required parameters
            % X , Y , ntr

            checkX = @(x) size(x,1) > 0 && size(x,2) > 0;
            checkY = @(x) size(x,1) > 0 && size(x,2) > 0;
            checkNtr = @(x) x > 0;
            
            addRequired(p,'X',checkX);
            addRequired(p,'Y',checkY);
            addRequired(p,'ntr',checkNtr);
            
 
            %%%% Optional parameters
            % Optional parameter names:
            % numNysParGuesses , maxRank , numMapParGuesses , mapParGuesses , filterParGuesses , numMapParRangeSamples  , verbose
            
            % numNysParGuesses       % Cardinality of number of samples for Nystrom approximation parameter guesses
            defaultNumNysParGuesses = [];
            checkNumNysParGuesses = @(x) x > 0 ;            
            addParameter(p,'numNysParGuesses',defaultNumNysParGuesses,checkNumNysParGuesses);                    
            
            % minRank        % Minimum rank of the Nystrom approximation
            defaultMinRank = 1;
            checkMinRank = @(x) x > 0 ;            
            addParameter(p,'minRank',defaultMinRank,checkMinRank);        
            
            % maxRank        % Maximum rank of the Nystrom approximation
            defaultMaxRank = [];
            checkMaxRank = @(x) x > 0 ;            
            addParameter(p,'maxRank',defaultMaxRank,checkMaxRank);        
            
            % numMapParGuesses        % Number of map parameter guesses
            defaultNumMapParGuesses = [];
            checkNumMapParGuesses = @(x) x > 0 ;            
            addParameter(p,'numMapParGuesses',defaultNumMapParGuesses,checkNumMapParGuesses);        
            
            % mapParGuesses        % Map parameter guesses
            defaultMapParGuesses = [];
            checkMapParGuesses = @(x) size(x,1) > 0 && size(x,2) > 0 ;      
            addParameter(p,'mapParGuesses',defaultMapParGuesses,checkMapParGuesses);        
            
            % filterParGuesses       % Filter parameter guesses
            defaultFilterPar = [];
            checkFilterPar = @(x) x > 0;            
            addParameter(p,'filterPar',defaultFilterPar,checkFilterPar);                    
            
            % numMapParRangeSamples        % Number of map parameter guesses
            defaultNumMapParRangeSamples = [];
            checkNumMapParRangeSamples = @(x) x > 0 ;            
            addParameter(p,'numMapParRangeSamples',defaultNumMapParRangeSamples,checkNumMapParRangeSamples);            

            % verbose             % 1: verbose; 0: silent      
            defaultVerbose = 0;
            checkVerbose = @(x) (x == 0) || (x == 1) ;            
            addParameter(p,'verbose',defaultVerbose,checkVerbose);
            
            % Parse function inputs
            if isempty(varargin{:})
                parse(p, X , Y , ntr)
            else
                parse(p, X , Y , ntr , varargin{:}{:})
            end
            
            % Assign parsed parameters to object properties
            fields = fieldnames(p.Results);
            for idx = 1:numel(fields)
                obj.(fields{idx}) = p.Results.(fields{idx});
            end
            
            % Joint parameters parsing
            if obj.minRank > obj.maxRank
                error('The specified minimum rank of the kernel approximation is larger than the maximum one.');
            end 
            
            if isempty(obj.mapParGuesses) && isempty(obj.numMapParGuesses)
                error('either mapParGuesses or numMapParGuesses must be specified');
            end    
            
            if (~isempty(obj.mapParGuesses)) && (~isempty(obj.numMapParGuesses)) && (size(obj.mapParGuesses,2) ~= obj.numMapParGuesses)
                error('The size of mapParGuesses and numMapParGuesses are different');
            end
            
            if ~isempty(obj.mapParGuesses) && isempty(obj.numMapParGuesses)
                obj.numMapParGuesses = size(obj.mapParGuesses,2);
            end
            
            if size(X,1) ~= size(Y,1)
                error('X and Y have incompatible sizes');
            end
            
            obj.d = size(X , 2);
            obj.t = size(Y , 2);
            
            display('Kernel used by nystromUniformIncremental is set to @gaussianKernel');
            obj.kernelType = @gaussianKernel;

            % Conditional range computation
            if obj.verbose == 1
                display('Computing range');
            end
            obj.range();    % Compute range
            obj.currentParIdx = 0;
            obj.currentPar = [];
        end

        function obj = range(obj)
            
            % Compute range of number of sampled columns (m)
            tmpm = round(linspace(obj.minRank, obj.maxRank , obj.numNysParGuesses));   

            % Approximated kernel parameter range
            
            if isempty(obj.mapParGuesses)
                % Compute max and min sigma guesses

                % Extract an even number of samples without replacement  
                
                nRows = size(obj.X,1); % number of rows
                nSample = obj.numMapParRangeSamples - mod(obj.numMapParRangeSamples,2); % number of samples
                
                rndIDX = [];
                while length(rndIDX) < nSample
                    rndIDX = [rndIDX , randperm(nRows , min( [ nSample , nRows , nSample - length(rndIDX) ] ) ) ];
                end
                
                samp = obj.X(rndIDX, :);   
                
                % Compute squared distances  vector (D)
                numDistMeas = floor(obj.numMapParRangeSamples/2); % Number of distance measurements
                D = zeros(1 , numDistMeas);
                for i = 1:numDistMeas
                    D(i) = sum((samp(2*i-1,:) - samp(2*i,:)).^2);
                end
                D = sort(D);

                fifthPercentile = round(0.05 * numel(D) + 0.5);
                ninetyfifthPercentile = round(0.95 * numel(D) - 0.5);
                minGuess = sqrt( D(fifthPercentile));
                maxGuess = sqrt( D(ninetyfifthPercentile) );
                
                if minGuess <= 0
                    minGuess = eps;
                end
                if maxGuess <= 0
                    maxGuess = eps;
                end	

                tmpMapPar = linspace(minGuess, maxGuess , obj.numMapParGuesses);
            else
                tmpMapPar = obj.mapParGuesses;
            end

            % Generate all possible parameters combinations
            [p,q] = meshgrid(tmpMapPar, tmpm);
            tmp = [q(:) p(:)]';
            obj.rng = tmp;

        end
        
        % Computes the squared distance matrix SqDistMat based on X1, X2
        function computeSqDistMat(obj , X1 , X2)
            
            if ~isempty(X1)
                obj.X1 = X1;
                obj.Sx1 = sum( X1.*X1 , 2);
            end
            if ~isempty(X2)
                obj.X2 = X2;
                obj.Sx2 = sum( X2.*X2 , 2)';
            end
            if ~isempty(X1) && ~isempty(X2)
                Sx1x2 = X1 * X2';
                obj.SqDistMat = repmat(obj.Sx1 , 1 , size(X2,1)) -2*Sx1x2 + repmat(obj.Sx2 , size(X1,1) , 1);
            elseif isempty(X1) && ~isempty(X2)
                Sx1x2 = obj.X1 * X2';
                obj.SqDistMat = repmat(obj.Sx1 , 1 , size(X2,1)) -2*Sx1x2 + repmat(obj.Sx2 , size(obj.X1,1) , 1);
            elseif ~isempty(X1) && isempty(X2)
                Sx1x2 = X1 * obj.X2';
                obj.SqDistMat = repmat(obj.Sx1 , 1 , size(obj.X2,1)) -2*Sx1x2 + repmat(obj.Sx2 , size(X1,1) , 1);
            end
        end
        
        function compute(obj , mapPar)
            
            if( nargin > 1 )
                
%                 if(obj.verbose == 1)
%                     disp('Mapping will be computed according to the provided hyperparameter(s)');
%                     mapPar
%                 end
                chosenPar = mapPar;
            elseif (nargin == 1) && (isempty(obj.currentPar))
                
                % If any current value for any of the parameters is not available, abort.
                error('Mapping parameter(s) not explicitly specified, and some internal current parameters are not available available. Exiting...');
            else
%                 if(obj.verbose == 1)
%                     disp('Mapping will be computed according to the current internal hyperparameter(s)');
%                     obj.currentPar
%                 end
                chosenPar = obj.currentPar;
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Incremental Update Rule %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%

            if (isempty(obj.prevPar) && obj.currentParIdx == 1) || (~isempty(obj.prevPar) && obj.currentPar(1) < obj.prevPar(1))
                
                %%% Initialization (i = 1)
                
                % Preallocate matrices
                
                obj.A = zeros(obj.ntr , obj.maxRank);
                obj.Aty = zeros(obj.maxRank , obj.t);
                
                obj.R = zeros(obj.maxRank);
                obj.alpha = zeros(obj.maxRank,size(obj.Y,2));
                
                sampledPoints = 1:chosenPar(1);
                obj.s = chosenPar(1);  % Number of new columns
                obj.Xs = obj.X(sampledPoints,:);
                obj.computeSqDistMat(obj.X , obj.Xs);
                
                obj.A(:,1:chosenPar(1)) = exp(-obj.SqDistMat / (2 * chosenPar(2)^2));
                B = obj.A(sampledPoints,1:chosenPar(1));
                obj.Aty(1:chosenPar(1),:) = obj.A(:,1:chosenPar(1))' * obj.Y;

                obj.R(1:chosenPar(1),1:chosenPar(1)) = ...
                    chol(full(obj.A(:,1:chosenPar(1))' * obj.A(:,1:chosenPar(1)) ) + ...
                    obj.ntr * obj.filterPar * B);

                % alpha
                obj.alpha = obj.R(1:chosenPar(1),1:chosenPar(1)) \ ...
                    ( obj.R(1:chosenPar(1),1:chosenPar(1))' \ ...
                    ( obj.Aty(1:chosenPar(1),:) ) );
                
            elseif obj.prevPar(1) ~= chosenPar(1)
               
                %%% Generic i-th incremental update step
                
                %Sample new columns of K
                sampledPoints = (obj.prevPar(1)+1):chosenPar(1);
                obj.s = chosenPar(1) - obj.prevPar(1);  % Number of new columns
                XsNew = obj.X(sampledPoints,:);
                obj.Xs = [ obj.Xs ; XsNew ];
                
                if isempty(obj.Sx1)
                    obj.computeSqDistMat(obj.X , XsNew);
                else
                    obj.computeSqDistMat([] , XsNew);
                end
                
                % Computer a, b, beta
                a = exp(-obj.SqDistMat / (2 * chosenPar(2)^2)) ;
                b = a( 1:obj.prevPar(1) , : );
                beta = a( sampledPoints , : );

                % Compute c, gamma
                c = obj.A(:,1:obj.prevPar(1))' * a + obj.ntr * obj.filterPar * b;
                gamma = a' * a + obj.ntr * obj.filterPar * beta;

                % Update A, Aty
                obj.A( : , (obj.prevPar(1)+1) : chosenPar(1) ) = a ;
                obj.Aty((obj.prevPar(1)+1) : chosenPar(1) , : ) = a' * obj.Y ;

                % Compute u, v
                u = [ c / ( 1 + sqrt( 1 + gamma) ) ; ...
                                sqrt( 1 + gamma)               ];

                v = [ c / ( 1 + sqrt( 1 + gamma) ) ; ...
                                -1               ];

                % Update R
                obj.R(1:chosenPar(1),1:chosenPar(1)) = ...
                    cholupdatek( obj.R(1:chosenPar(1),1:chosenPar(1)) , u , '+');

                obj.R(1:chosenPar(1),1:chosenPar(1)) = ...
                    cholupdatek(obj.R(1:chosenPar(1),1:chosenPar(1)) , v , '-');

                % Recompute alpha
                obj.alpha = obj.R(1:chosenPar(1),1:chosenPar(1)) \ ...
                    ( obj.R(1:chosenPar(1),1:chosenPar(1))' \ ...
                    ( obj.Aty(1:chosenPar(1),:) ) );
            end
        end
        
        function resetPar(obj)
            
            obj.currentParIdx = 0;
            obj.currentPar = [];
        
        end
        
        % returns true if the next parameter combination is available and
        % updates the current parameter combination 'currentPar'
        function available = next(obj)

            % If any range for any of the parameters is not available, recompute all ranges.
            if isempty(obj.rng)
                obj.range();
            end
            
            available = false;
            if size(obj.rng,2) > obj.currentParIdx
                obj.prevPar = obj.currentPar;
                obj.currentParIdx = obj.currentParIdx + 1;
                obj.currentPar = obj.rng(:,obj.currentParIdx);
                available = true;
            end
        end
    end
end
