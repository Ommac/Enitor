classdef randomFeaturesGaussianIncremental < randomFeatures
    % 
    %
    % Input parameters:
    % TO DO.

    
    properties
                
        numRFParGuesses
        verbose
        
        numMapParRangeSamples   % Number of samples of X considered for estimating the maximum and minimum sigmas
        maxRank                 % Maximum rank of the kernel approximation
        minRank                 % Minimum rank of the kernel approximation
        
        filterParGuesses        % Filter parameter guesses
        numFilterParGuesses     % Number of filter parameter guesses
        
        mapParGuesses           % mapping parameter guesses
%         numMapParGuesses        % Number of mapping parameter guesses
        
        kernelType      % Type of approximated kernel
        SqDistMat       % Squared distances matrix
        Y               % Training outputs
        Xs              % Sampled points
        
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
        
        function obj = randomFeaturesGaussianIncremental( X , Y , ntr , varargin)
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
            % numRFParGuesses , maxRank , numMapParGuesses , mapParGuesses , filterParGuesses , numMapParRangeSamples  , verbose
            
            % numRFParGuesses       % Cardinality of number of samples for Nystrom approximation parameter guesses
            defaultNumRFParGuesses = [];
            checkNumRFParGuesses = @(x) x > 0 ;            
            addParameter(p,'numRFParGuesses',defaultNumRFParGuesses,checkNumRFParGuesses);                    
            
            % minRank        % Minimum rank of the RF approximation
            defaultMinRank = [];
            checkMinRank = @(x) x > 0 ;            
            addParameter(p,'minRank',defaultMinRank,checkMinRank);        
            
            % maxRank        % Maximum rank of the RF approximation
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
            defaultFilterParGuesses = [];
            checkFilterParGuesses = @(x) size(x,1) > 0 && size(x,2) > 0 ;            
            addParameter(p,'filterParGuesses',defaultFilterParGuesses,checkFilterParGuesses);                    
            
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
%             fieldsToIgnore = {'X1','X2'};
%             fields = setdiff(fields, fieldsToIgnore);
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
            
            display('Kernel used by randomFeaturesGaussianIncremental is set to @gaussianKernel');
            obj.kernelType = @gaussianKernel;

            % Conditional range computation
%             if isempty(obj.mapParGuesses)
            if obj.verbose == 1
                display('Computing range');
            end
            obj.range();    % Compute range
%             end
            obj.currentParIdx = 0;
            obj.currentPar = [];
        end

        function mappedSample = map(obj , inputSample , partialRange)
            
            % [cos sin] mapping
%             V = inputSample * obj.omega;
%             mappedSample = sqrt( 2 / obj.currentPar(1) ) * [cos(V) , sin(V)];
            
            if isempty(partialRange)
%                 Full cos(wx+b) mapping
                V =  inputSample * obj.omega + repmat(obj.b , size(inputSample,1) , 1);            
%                 mappedSample = sqrt( 2 / obj.currentPar(1) ) * cos(V);
                mappedSample = cos(V);
            else
                % Partial cos(wx+b) mapping
                V =  inputSample * obj.omega(:,partialRange) + repmat(obj.b(partialRange) , size(inputSample,1) , 1);            
%                 mappedSample = sqrt( 2 / obj.currentPar(1) ) * cos(V);
                mappedSample = cos(V);
            end
        end
        
        function obj = range(obj)
                        
            % Range of the number of Random Fourier Features
            tmpNumRF = round(linspace(obj.minRank, obj.maxRank , obj.numRFParGuesses));   
           
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
            [p,q] = meshgrid(tmpMapPar, tmpNumRF);
            tmp = [q(:) p(:)]';
            obj.rng = tmp;

        end
        
        function compute(obj , mapPar)
            
            if( nargin > 1 )
                
                if(obj.verbose == 1)
                    disp('Mapping will be computed according to the provided hyperparameter(s)');
                    mapPar
                end
                chosenPar = mapPar;
            elseif (nargin == 1) && (isempty(obj.currentPar))
                
                % If any current value for any of the parameters is not available, abort.
                error('Mapping parameter(s) not explicitly specified, and some internal current parameters are not available available. Exiting...');
            else
                if(obj.verbose == 1)
                    disp('Mapping will be computed according to the current internal hyperparameter(s)');
                    obj.currentPar
                end
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
                
                obj.R = cell(size(obj.filterParGuesses));
                [obj.R{:,:}] = deal(zeros(obj.maxRank));
                
                obj.alpha = cell(size(obj.filterParGuesses));
                [obj.alpha{:,:}] = deal(zeros(obj.maxRank,size(obj.Y,2)));
                
                obj.s = chosenPar(1);
                [obj.omega , obj.b] = obj.generateProj(chosenPar);

                % Set Xs
                obj.Xs = obj.map(obj.X , []);

                obj.A(:,1:chosenPar(1)) = obj.Xs;
                B = eye(chosenPar(1),chosenPar(1));
                obj.Aty(1:chosenPar(1),:) = obj.A(:,1:chosenPar(1))' * obj.Y;

                for i = 1:size(obj.filterParGuesses,2)
                    
                    obj.R{i}(1:chosenPar(1),1:chosenPar(1)) = ...
                        chol(full(obj.A(:,1:chosenPar(1))' * obj.A(:,1:chosenPar(1)) ) + ...
                        obj.ntr *  obj.filterParGuesses(i) * B);
                    
                    % alpha
                    obj.alpha{i} = 	obj.R{i}(1:chosenPar(1),1:chosenPar(1)) \ ...
                        ( obj.R{i}(1:chosenPar(1),1:chosenPar(1))' \ ...
                        ( obj.Aty(1:chosenPar(1),:) ) );
                end
                
            elseif obj.prevPar(1) ~= chosenPar(1)
               
                %%% Generic i-th incremental update step
               
                sampledPoints = (obj.prevPar(1) + 1):chosenPar(1);                
                obj.s = chosenPar(1) - obj.prevPar(1);  % Number of new columns
     
                % Generate new random projections
                [newOmega , newB] = obj.generateProj([obj.s ; chosenPar(2)]);
                obj.omega = [obj.omega , newOmega];
                obj.b = [obj.b , newB];
                
                % Compute a
                a = obj.map(obj.X , sampledPoints) ;
                
                % Update Xs_(t+1)
                obj.Xs = [obj.Xs a];    
                
                % Cycle over filter parameter
                for i = 1:size(obj.filterParGuesses,2)
                    
                    % Compute c, gamma
                    c = obj.A(:,1:obj.prevPar(1))' * a; % + obj.ntr * chosenPar(1) * obj.filterParGuesses(i) * zeros(size(b));
                    gamma = a' * a + obj.ntr * chosenPar(1) * obj.filterParGuesses(i) * eye(numel(sampledPoints));

                    % Update A, Aty
                    obj.A( : , (obj.prevPar(1)+1) : chosenPar(1) ) = a ;
                    obj.Aty((obj.prevPar(1)+1) : chosenPar(1) , : ) = a' * obj.Y ;
                    
                    % Compute u, v
                    u = [ c / ( 1 + sqrt( 1 + gamma) ) ; ...
                                    sqrt( 1 + gamma)               ];
                    
                    v = [ c / ( 1 + sqrt( 1 + gamma) ) ; ...
                                    -1               ];
                               
                    % Update R
                    obj.R{i}(1:obj.prevPar(1),1:obj.prevPar(1)) = ...
                        obj.R{i}(1:obj.prevPar(1),1:obj.prevPar(1)) + ...
                        sqrt(obj.ntr * obj.filterParGuesses(i)) * eye(obj.prevPar(1));
                    
                    obj.R{i}(1:chosenPar(1),1:chosenPar(1)) = ...
                        cholupdatek( obj.R{i}(1:chosenPar(1),1:chosenPar(1)) , u , '+');
                    try
                    obj.R{i}(1:chosenPar(1),1:chosenPar(1)) = ...
                        cholupdatek(obj.R{i}(1:chosenPar(1),1:chosenPar(1)) , v , '-');
                    catch
                        display('test');
                    end
                    % Recompute alpha
                    obj.alpha{i} = 	obj.R{i}(1:chosenPar(1),1:chosenPar(1)) \ ...
                        ( obj.R{i}(1:chosenPar(1),1:chosenPar(1))' \ ...
                        ( obj.Aty(1:chosenPar(1),:) ) );
                end
            end
        end
        
        function resetPar(obj)
            
            obj.currentParIdx = 0;
            obj.currentPar = [];
        
        end
        
        function [omega , b] = generateProj(obj , mapPar)

            omega =  randn(obj.d, mapPar(1)) / mapPar(2);
            b =  rand(1,mapPar(1))* 2 * pi;
        end

        % returns true if the next parameter combination is available and
        % updates the current parameter combination 'currentPar'
        function available = next(obj)

            % If any range for any of the parameters is not available, recompute all ranges.
%             if cellfun(@isempty,obj.mapParGuesses)
%                 obj.range();
%             end
            if isempty(obj.rng)
                obj.range();
            end
            
            available = false;
%             if length(obj.mapParGuesses) > obj.currentParIdx
%                 obj.currentParIdx = obj.currentParIdx + 1;
%                 obj.currentPar = obj.mapParGuesses{obj.currentParIdx};
%                 available = true;
%             end
            if size(obj.rng,2) > obj.currentParIdx
                obj.prevPar = obj.currentPar;
                obj.currentParIdx = obj.currentParIdx + 1;
                obj.currentPar = obj.rng(:,obj.currentParIdx);
                available = true;
            end
        end
    end
end
