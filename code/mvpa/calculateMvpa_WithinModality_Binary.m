function accu = calculateMvpa_WithinModality_Binary(opt)

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
                'imagePath', []);
            
    %% MVPA options
    decodingConditionList = {'OlfaWord_vs_NonOlfaWord','OlfaPicture_vs_NonOlfaPicture'};
    
    %% set masks 
%     %(outside the subject loop because the masks are not subject-specific)
%     
%     %get the masks/ROIs to be used
%     opt.maskPath = fullfile(fileparts(mfilename('fullpath')), '..','..', 'outputs','derivatives' ,'rois');
% 
%     % Mask filenames 
%     opt.maskName = { ...
%         'atlas-AAL3_space-MNI_hemi-L_desc-acc_mask.nii', ...
%         'atlas-AAL3_space-MNI_hemi-R_desc-acc_mask.nii', ...
%         'atlas-AAL3_space-MNI_hemi-L_desc-insula_mask.nii', ...
%         'atlas-AAL3_space-MNI_hemi-R_desc-insula_mask.nii', ...
%         'atlas-AAL3_space-MNI_hemi-L_desc-ofcmed_mask.nii', ...
%         'atlas-AAL3_space-MNI_hemi-R_desc-ofcmed_mask.nii' ...
%         };
% 
%     % Labels used for output ROI names, use in output roi name
%     opt.maskLabel = {'lACC', 'rACC', 'lInsula', 'rInsula', 'lOFCmed', 'rOFCmed'};
    
     %% set masks 
    %(outside the subject loop because the masks are not subject-specific)
    
    %get the masks/ROIs to be used
    opt.maskPath = fullfile(fileparts(mfilename('fullpath')), '..','..', 'outputs','derivatives' ,'rois');

    % Mask filenames 
    opt.maskName = { ...
        'atlas-Glasser_space-MNI_hemi-L_desc-insula-anterior_mask.nii', ...
        'atlas-Glasser_space-MNI_hemi-L_desc-insula-middle_mask.nii', ...
        'atlas-Glasser_space-MNI_hemi-L_desc-insula-posterior_mask.nii', ...
        'atlas-Glasser_space-MNI_hemi-R_desc-insula-anterior_mask.nii', ...
        'atlas-Glasser_space-MNI_hemi-R_desc-insula-middle_mask.nii', ...
        'atlas-Glasser_space-MNI_hemi-R_desc-insula-posterior_mask.nii' ...
        };

    % Labels used for output ROI names, use in output roi name
    opt.maskLabel = {'lAnteriorInsula', 'lMiddleInsula', 'lPosteriorInsula',...
        'rAnteriorInsula', 'rMiddleInsula', 'rPosteriorInsula'};
    
    %% starting mvpa for a subject 
    % Iqra suggestion combine 4d images, faire en sorte d'avoir tt les
    % 4 conditions dans la même 4d file.
    count = 1;
    for iSub = 1:numel(opt.subjects) %set subject
        subID = opt.subjects{iSub}; %     ffxDir = getFFXdir(subID, funcFWHM, opt);
        disp(opt.subjects{iSub});
        
        for iImage = 1:length(opt.mvpa.map4D) %set 4D image
            imageType = opt.mvpa.map4D{iImage};
            imageName = ['sub-',num2str(subID),'_task-',char(opt.taskName),'_space-IXI549Space',...
                '_desc-4D_', imageType,'.nii'];
            image=char(fullfile(fileparts(mfilename('fullpath')),'..', '..','outputs','derivatives',...
                'bidspm-stats',strcat('sub-',subID),...
                strcat('task-',opt.taskName,'_space-IXI549Space','_FWHM-',num2str(opt.funcFWHM)),...
                imageName));
            disp(imageName);
            
            for iMask = 1:length(opt.maskLabel)
                mask = fullfile(opt.maskPath, opt.maskName{iMask});
                disp(opt.maskName{iMask});
                
                for iDecodingCondition = 1:length(decodingConditionList)
                    decodingCondition=decodingConditionList{iDecodingCondition};
                    
                    % load cosmo input
                    ds = cosmo_fmri_dataset(image, 'mask', mask); % don't do this and follow the steps below 

                    %step 1: ds1 = cosmo_fmri_dataset(4-D image of the pictures)
                    %step 2: ds2 = cosmo_fmri_dataset(4-D image of the words)
                    % step 3: concatenate or combine the two ds1 and ds2 one after the other and call  it ds
                    % step 4: ds= ds1;ds2 -> ds = cosmo_stack({ds1, ds2});
                    
                    % remove constant features
                    %The input dataset has NaN (not a number) values, which may cause the output of subsequent
                    %analyses to contain NaNs as well. For many use cases, NaNs are not desirabe. 
                    %To remove features (voxels) with NaN values
                    ds = cosmo_remove_useless_data(ds);

                    % Getting rid off zeros
                    zeroMask = all(ds.samples == 0, 1); %checks column-wise:“Are all rows in this column true?
                    ds = cosmo_slice(ds, ~zeroMask, 2);
                    
                    % set cosmo mvpa structure
                    condLabelNb = [1 2 3 4 5 6 ]; % ici 1 to 4 (4 conditions)
                    condLabelName = {'OlfaWord', 'NonOlfaWord', 'OlfaPicture', 'NonOlfaPicture'}; % vérifier que l'ordre est correct!!
                    ds = setCosmoStructure(opt, ds, condLabelNb, condLabelName);
                    
%                     % Demean  every pattern to remove univariate effect differences
%                     % Sample-wise demeaning = subtract sample mean across voxels (row-wise)
%                     meanPattern = mean(ds.samples,2);  % get the mean for every pattern
%                     meanPattern = repmat(meanPattern,1,size(ds.samples,2)); % make a matrix with repmat
%                     ds.samples  = ds.samples - meanPattern; % remove the mean from every every point in each pattern
                    
                    % calculate the mask size
                    maskVoxel = size(ds.samples, 2);

                    % slice the ds according to your targers (choose your
                    % train-test conditions

                    switch decodingCondition
                        case 'tHigh_vs_tMed'
                            keepLabels = condLabelNb([1 2]);
                        case 'tHigh_vs_tLow'
                            keepLabels = condLabelNb([1 3]);
                        case 'tMed_vs_tLow'
                            keepLabels = condLabelNb([2 3]);
                        case 'vHigh_vs_vMed'
                            keepLabels = condLabelNb([4 5]);
                        case 'vHigh_vs_vLow'
                            keepLabels = condLabelNb([4 6]);
                        case 'vMed_vs_vLow'
                            keepLabels = condLabelNb([5 6]);
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
                    
                    % Feature-wise demeaning = subtract voxel mean across samples (column-wise)
                    opt.mvpa.normalization = 'zscore'; %'demean'

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
                    accu(count).imagePath = image;                    

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
