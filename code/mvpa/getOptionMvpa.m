% (C) Copyright 2019 CPP BIDS SPM-pipeline developpers

function opt = getOptionMvpa()
  % returns a structure that contains the options chosen by the user to run
  % decoding with cosmo-mvpa.

  if nargin < 1
    opt = [];
  end

  % suject to run in each group
  opt.subjects = {'001'}; % On run un à la fois? 
         
  % Uncomment the lines below to run preprocessing
  % - don't use realign and unwarp
  opt.realign.useUnwarp = true;

  % we stay in native space (that of the T1)
  opt.space ='MNI';

  % The directory where the data are located
  opt.pathOutput = fullfile(fileparts(mfilename('fullpath')),'..', '..','outputs','derivatives',...
      'mvpa_decoding'); % créer un rep mvpa_decoding avec les résultats 
  
  % multivariate
  opt.model.file = fullfile(fileparts(mfilename('fullpath')), '..', ...
                            'model', 'model-olfa_smdl_pictures_HP160.json'); % the one in b_ex_multivar
  
  % task to analyze
  opt.taskName = 'olfaPictures'; %or olfaWords

  opt.parallelize.do = false;
  opt.parallelize.nbWorkers = 1;
  opt.parallelize.killOnExit = true;

  %% DO NOT TOUCH
  opt = checkOptions(opt);
  saveOptions(opt);
  % we cannot save opt with opt.mvpa, it crashes

  %% mvpa options
  % mask/ROIs used
  opt.maskVoxelNb = 100;
  
  opt.maskRadiusNb=8;

  % define the 4D maps to be used
  opt.funcFWHM = 2;

  % take the most responsive xx nb of voxels
  opt.mvpa.ratioToKeep = 100; 

  % set which type of ffx results you want to use
  opt.mvpa.map4D = {'beta','tmap'};%

  % design info
  opt.mvpa.nbRun = 6;
  opt.mvpa.nbTrialRepetition = 1;

  % cosmo options
  opt.mvpa.tool = 'cosmo';
%   opt.mvpa.normalization = 'zscore'; %'demean'
  opt.mvpa.child_classifier = @cosmo_classify_libsvm; 
  opt.mvpa.feature_selector = @cosmo_anova_feature_selector;

  % permute the accuracies ?
  opt.mvpa.permutate = 0; % keep 0 for now! for stats change to 1
  
end
