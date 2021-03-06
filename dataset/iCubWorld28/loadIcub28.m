function [Xtr, Ytr, Xte, Yte] = ...
    loadIcub28(ntr, nte, classes, trainClassFreq, testClassFreq, trainClassNum, testClassNum, dataRoot, trainFolder, testFolder)


    ICUBWORLDopts = ICUBWORLDinit('iCubWorld30');
    obj_names = keys(ICUBWORLDopts.objects)';
    numClasses = numel(classes); % number of classes
%     if (numel(trainClassFreq) ~= numel(testClassFreq))  || (numel(trainClassFreq) ~= numClasses)
%         error('Number of classes and class frequencies specifications differ.')
%     end
    
    if ( ~isempty(trainClassFreq) && ~isempty(trainClassNum) ) || (~isempty(testClassFreq) && ~isempty(testClassNum) )
        error('Only  frequency or number of samples can be specified at the same time.');
    end
%     
%     if ( isempty(trainClassFreq) && isempty(trainClassNum) ) || (isempty(testClassFreq) && isempty(testClassNum) )
% 
%     end
    

    dataset_train = Features.GenericFeature();
    dataset_test = Features.GenericFeature();

    fullfilepath = which('loadIcub28.m');
    [pathstr,~,~] = fileparts(fullfilepath);
    train_root = [pathstr , '/' , dataRoot, 'train/' , trainFolder]; % '/home/kammo/Repos/ior/data/caffe_centralcrop_meanimagenet2012/train/lunedi22';
    test_root = [pathstr , '/' , dataRoot, 'test/' , testFolder]; % '/home/kammo/Repos/ior/data/caffe_centralcrop_meanimagenet2012/test/martedi23';

    feat_ext = '.mat';

    dataset_train.load_feat(train_root, [], feat_ext, [], []);
    dataset_test.load_feat(test_root, [], feat_ext, [], []);

    XtrTmp = dataset_train.Feat';
    XteTmp = dataset_test.Feat';

    YtrTmp = create_y(dataset_train.Registry, obj_names, []);
    YteTmp = create_y(dataset_test.Registry, obj_names, []);

    classIdxTr = cell(1,numClasses);
    classIdxTe = cell(1,numClasses);
    for i = 1:numClasses
        classIdxTr{i} = find(YtrTmp(:,classes(i)) == 1);
        classIdxTe{i} = find(YteTmp(:,classes(i)) == 1);
    end

    Xtr = [];
    Xte = [];
    Ytr = [];
    Yte = [];
 
    minNumSamplesPerClass = inf;
    for i = 1:numClasses
        Xtr = [ Xtr ; XtrTmp(classIdxTr{i},:)];
        Xte = [ Xte ; XteTmp(classIdxTe{i},:)];
        Ytr = [ Ytr ; YtrTmp(classIdxTr{i},classes)];
        Yte = [ Yte ; YteTmp(classIdxTe{i},classes)];
        
        classIdxTr{i} = size(Ytr,1) - numel(classIdxTr{i}) + 1 : size(Ytr,1);
        classIdxTe{i} = size(Ytr,1) - numel(classIdxTe{i}) + 1 : size(Yte,1);
        
        if numel(classIdxTr{i}) < minNumSamplesPerClass
            
            minNumSamplesPerClass = numel(classIdxTr{i});
        end
    end
    
    % Compute number of training points per class for training set
    if ~isempty(trainClassFreq) && isempty(trainClassNum)
        % Apply training class frequencies
        trainClassNum = [];
        for i = 1:numClasses    
            trainClassNum = [trainClassNum , round((trainClassFreq(i) * minNumSamplesPerClass)/max(trainClassFreq)) ];
        end
    elseif isempty(trainClassNum) && isempty(trainClassFreq) 
        
        display('trainClassFreq and trainClassNum not specified. All the raw training points of all classes will be loaded.');
        trainClassFreq = ones(1,numClasses) * 1/numel(classes);
        
        % Apply training class frequencies
        trainClassNum = [];
        for i = 1:numClasses    
            trainClassNum = [trainClassNum , round((trainClassFreq(i) * numel(classIdxTr{i}))/max(trainClassFreq)) ];
        end
    end

    
    % Shuffle idx
    trainIdx = cell(1,numClasses);
    for i = 1:numClasses
        trainIdx{i} = classIdxTr{i}(randperm(numel(classIdxTr{i}),trainClassNum(i)));
    end

    

    if ~isempty(nte) && nte > size(Xte,1)
        error( ['Maximum nte = ' , num2str(size(Xte,1))] );
    elseif isempty(nte)
        nte = size(Xte,1);
    end
    
    testIdx = randperm(size(Yte,1),nte);

    Xtrtmp = [];
    Ytrtmp = [];
    for i = 1:numClasses
        Xtrtmp = [Xtrtmp ; Xtr(trainIdx{i},:)];
        Ytrtmp = [Ytrtmp ; Ytr(trainIdx{i},:)];
    end

    Xtr = Xtrtmp;
    Ytr = Ytrtmp;

    clear Xtrtmp Ytrtmp;

    if ~isempty(ntr) && ntr > size(Xtr,1)
        error( ['Maximum ntr = ' , num2str(size(Xtr,1))] );
    elseif isempty(ntr)
        ntr = size(Xtr,1);
%         display( ['ntr set to ' , num2str(size(Xtr,1))] );
    end
    trainIdx2 = randperm(size(Ytr,1),ntr);

    Xtr = Xtr(trainIdx2,:);
    Ytr = Ytr(trainIdx2,:);

    Xte = Xte(testIdx,:);
    Yte = Yte(testIdx,:);

end