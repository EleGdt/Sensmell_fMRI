function accu = calculateMvpa_WithinModality_Binary_modified(opt)

    %% set output folder/name
    savefileMat = fullfile(opt.pathOutput, ...
                         [char(opt.taskName), ...
                         '_withinModal_binary',...
                          '_smoothing', num2str(opt.funcFWHM), ...
                          '_ratio', num2str(opt.mvpa.ratioToKeep), ...
                          '_', datestr(now, 'yyyymmddHHMM'), '.mat']);
                      
    %% set structure array for keeping the results
    accu = struct( ...
                'subID', [], ...
                'mask', [], ...
                'maskVoxNb', [], ...
                'choosenVoxNb', [], ...
                'ffxSmooth', [], ...
                'image', [], ...
                'decodingCondition', [], ...
                'accuracy', [], ...
                'prediction', [], ...
                'confusionMatrixPerFold', [], ...
                'classLabels', [], ...
                'confusionMatrix', [], ...
                'accuFromConfMat', [], ...
                'permutation', [], ...
                'imagePathA', [],...
                'imagePathB', []);
            
    %% MVPA options
    decodingConditionList = {'olfaPictures_vs_nonOlfaPictures','olfaWords_vs_nonOlfaWords',...
        'olfaPictures_vs_OlfaWords','nonOlfaPictures_vs_nonOlfaWords'};
    
    %% set masks 
    %(outside the subject loop because the masks are not subject-specific)
    
    %get the masks/ROIs to be used
    opt.maskPath = fullfile(fileparts(mfilename('fullpath')), '..','..', 'outputs','derivatives' ,'rois');

    % Mask filenames 
    opt.maskName = { ...
        'rROI_Amygdala_L_AAL3.nii', ...
        'rROI_Amygdala_R_AAL3.nii', ...
        'rROI_Caudate_L_AAL3.nii', ...
        'rROI_Caudate_R_AAL3.nii', ...
        'rROI_Hippocampus_L_AAL3.nii', ...
        'rROI_Hippocampus_R_AAL3.nii',...
        'rROI_Insula_L_AAL3.nii',...
        'rROI_Insula_R_AAL3.nii',...
        'rROI_PCC_L_AAL3.nii',...
        'rROI_PCC_R_AAL3.nii',...
        'rROI_Pir_Glasser.nii',...
        'rROI_Putamen_L_AAL3.nii',...
        'rROI_Putamen_R_AAL3.nii',...
        'rROI_V1_Glasser.nii',...
        };

    % Labels used for output ROI names, use in output roi name
    opt.maskLabel = {'lAmygdala', 'rAmygdala', 'lCaudate',...
        'rCaudate', 'lHippocampus', 'rHippocampus','lInsula',...
        'rInsula','lPCC','rPCC','Piriform','lPutamen'...
        'rPutamen','V1'};
    
    %% starting mvpa for a subject 
    count = 1;
    for iSub = 1:numel(opt.subjects) %set subject
        subID = opt.subjects{iSub}; 
        disp(opt.subjects{iSub});
        
        for iImage = 1:length(opt.mvpa.map4D) %set 4D image
            imageType = opt.mvpa.map4D{iImage}; % set if you want to use beta maps or t-maps (images)

            % pick up the 4-D image
            % imageName = ['sub-',num2str(subID),'_task-',char(opt.taskName),'_space-IXI549Space',...
            %     '_desc-4D_', imageType,'.nii'];
            % image=char(fullfile(fileparts(mfilename('fullpath')),'..', '..','outputs','derivatives',...
            %     'bidspm-stats',strcat('sub-',subID),...
            %     strcat('task-',opt.taskName,'_space-IXI549Space','_FWHM-',num2str(opt.funcFWHM)),...
            %     imageName));
            % disp(imageName);

            %A : pick up the 4-D image from task name: olfaPictures
            imageNameA = ['sub-',num2str(subID),'_task-','olfaPictures','_space-IXI549Space',...
                '_desc-4D_', imageType,'.nii'];
            imageA=char(fullfile(fileparts(mfilename('fullpath')),'..', '..','outputs','derivatives',...
                'bidspm-stats',strcat('sub-',subID),...
                strcat('task-','olfaPictures','_space-IXI549Space','_FWHM-',num2str(opt.funcFWHM)),...
                imageNameA));
            disp(imageNameA);

            %B : pick up the 4-D image from task name: olfaWords
            imageNameB = ['sub-',num2str(subID),'_task-','olfaWords','_space-IXI549Space',...
                '_desc-4D_', imageType,'.nii'];
            imageB=char(fullfile(fileparts(mfilename('fullpath')),'..', '..','outputs','derivatives',...
                'bidspm-stats',strcat('sub-',subID),...
                strcat('task-','olfaWords','_space-IXI549Space','_FWHM-',num2str(opt.funcFWHM)),...
                imageNameB));
            disp(imageNameB);
            
            for iMask = 1:length(opt.maskLabel)
                mask = fullfile(opt.maskPath, opt.maskName{iMask});
                disp(opt.maskName{iMask});
                
                for iDecodingCondition = 1:length(decodingConditionList)
                    decodingCondition=decodingConditionList{iDecodingCondition};
                    
                    % load cosmo input
                    % ds = cosmo_fmri_dataset(image, 'mask', mask); %we
                    % take a new approach as follows:
                    % since the 4-D images are coming from two different
                    % tasks, we pick up the 4-D images , load them in to
                    % dsA and ds B
                    % and then concatenate/combine/merge the two ds. The
                    % subsequent classification will be done on the ds.
                    dsA = cosmo_fmri_dataset(imageA, 'mask', mask);
                    dsB = cosmo_fmri_dataset(imageB, 'mask', mask);
                    ds = cosmo_stack({dsA, dsB}); 
                    
                    % remove constant features
                    %The input dataset has NaN (not a number) values, which may cause the output of subsequent
                    %analyses to contain NaNs as well. For many use cases, NaNs are not desirabe. 
                    %To remove features (voxels) with NaN values
                    ds = cosmo_remove_useless_data(ds);

                    % Getting rid off zeros
                    zeroMask = all(ds.samples == 0, 1); %checks column-wise:“Are all rows in this column true?
                    ds = cosmo_slice(ds, ~zeroMask, 2);
                    
                    % set cosmo mvpa structure
                    condLabelNb = [1 2 3 4 ];
                    condLabelName = {'olfaPictures', 'nonOlfaPictures', 'olfaWords', 'nonOlfaWords'};
                    ds = setCosmoStructure(opt, ds, condLabelNb, condLabelName);
                    
                    % Demean  every pattern to remove univariate effect differences
                    % Sample-wise demeaning = subtract sample mean across voxels (row-wise)
                    meanPattern = mean(ds.samples,2);  % get the mean for every pattern
                    meanPattern = repmat(meanPattern,1,size(ds.samples,2)); % make a matrix with repmat
                    ds.samples  = ds.samples - meanPattern; % remove the mean from every every point in each pattern
                    
                    % calculate the mask size
                    maskVoxel = size(ds.samples, 2);

                    % slice the ds according to your targers (choose your
                    % train-test conditions

                    switch decodingCondition
                        case 'olfaPictures_vs_nonOlfaPictures'
                            keepLabels = condLabelNb([1 2]);
                        case 'olfaWords_vs_nonOlfaWords'
                            keepLabels = condLabelNb([3 4]);
                        case 'olfaPictures_vs_OlfaWords'
                            keepLabels = condLabelNb([1 3]);
                        case 'nonOlfaPictures_vs_nonOlfaWords'
                            keepLabels = condLabelNb([2 4]);
                        otherwise
                            error('Unknown decoding condition: %s', decodingCondition);
                    end
                    
                    ds = cosmo_slice(ds, ismember(ds.sa.targets, keepLabels));

                    % partitioning, for test and training : cross validation
                    partitions = cosmo_nfold_partitioner(ds);

                    % define the voxel number for feature selection
                    % set ratio to keep depending on the ROI dimension
                    % use the ratios, instead of the voxel number:
                    opt.mvpa.feature_selection_ratio_to_keep = opt.mvpa.ratioToKeep;

                    % ROI mvpa analysis
                    [pred, accuracy] = cosmo_crossvalidate(ds, ...
                                               @cosmo_classify_meta_feature_selection, ...
                                               partitions, opt.mvpa);
                                           
                   % compute confusion matrix per fold
                   %confusionMatrix(:,:,k) =
                   % [ trueClass1→predClass1   trueClass1→predClass2
                   %   trueClass2→predClass1   trueClass2→predClass2 ]
                   [confMat, classLabels] = cosmo_confusion_matrix(ds.sa.targets, pred); %confMat: 2×2×Nfolds
                   %2×2 confusion matrix per subject × ROI × contrast.
                   confMatPooled = sum(confMat, 3);% single pooled confusion matrix per analysis -> sum across folds
                   % For binary classification, accuracy should equal:
                   accuFromConfMat = trace(sum(confMat,3)) / sum(confMat(:));

                    %% store output
                    accu(count).subID = subID;
                    accu(count).mask = opt.maskLabel{iMask};
                    accu(count).maskVoxNb = maskVoxel; 
                    accu(count).choosenVoxNb = opt.mvpa.feature_selection_ratio_to_keep;
                    accu(count).ffxSmooth = opt.funcFWHM;
                    accu(count).image = opt.mvpa.map4D{iImage};
                    accu(count).decodingCondition = decodingCondition;
                    accu(count).accuracy = accuracy;
                    accu(count).prediction = pred;
                    accu(count).confusionMatrixPerFold = confMat;
                    accu(count).classLabels = classLabels;
                    accu(count).confusionMatrix = confMatPooled;
                    accu(count).accuFromConfMat = accuFromConfMat;
                    accu(count).imagePathA = imageA;    
                    accu(count).imagePathB = imageB;    

                    %% PERMUTATION PART
                    if opt.mvpa.permutate  == 1
                        % number of iterations
                        nbIter = 100;
                        
                        % allocate space for permuted accuracies
                        acc0 = zeros(nbIter, 1);
                        
                        % make a copy of the dataset
                        ds0 = ds;
                        
                        % for _niter_ iterations, reshuffle the labels and compute accuracy
                        % Use the helper function cosmo_randomize_targets
                        for k = 1:nbIter
                            ds0.sa.targets = cosmo_randomize_targets(ds);
                            [~, acc0(k)] = cosmo_crossvalidate(ds0, ...
                                @cosmo_meta_feature_selection_classifier, ...
                                partitions, opt.mvpa);
                        end
                        
                        p = sum(accuracy < acc0) / nbIter;
                        fprintf('%d permutations: accuracy=%.3f, p=%.4f\n', nbIter, accuracy, p);
                        
                        % save permuted accuracies
                        accu(count).permutation = acc0';
                    end
                    
                    % increase the counter and allons y!
                    count = count + 1;
                    
                    fprintf(['Sub'  subID ' - area: ' opt.maskLabel{iMask} ...
                        ', accuracy: ' num2str(accuracy) '\n\n\n']);

                end
            end
        end
    end
    
    %% save output
  % mat file
  save(savefileMat, 'accu');

end