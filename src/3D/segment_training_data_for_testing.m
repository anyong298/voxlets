% a script to process all the testing on themselves depth images
% will segment and then save the files back to disk
% no - for now will not both segmenting. Instead will just match from the
% database. Segmentation will be another layer
clear
cd ~/projects/shape_sharing/src/3D
addpath(genpath('src'))
addpath(genpath('../2D/src'))
addpath(genpath('../common/'))

define_params_3d
load(paths.structured_model_file, 'model')
%%
params.proposals.proposals_per_region = 2;
params.proposals.feature_vector = 'shape_dist';
params.proposals.load_voxels = false;
params.test_dataset.models_to_use = 100;

for ii = 1%:length(params.test_dataset.models_to_use)
    
    model3d.idx = params.test_dataset.models_to_use(ii);
    model3d.name = params.model_filelist{model3d.idx};
    load(sprintf(paths.basis_models.combined_file, model3d.name), 'renders')
   
    for view_idx = params.test_dataset.views_to_use(1)

        cloud = [];
        cloud.depth = renders(view_idx).depth;
        cloud.mask = ~isnan(cloud.depth);
        cloud.xyz = reproject_depth(cloud.depth, params.half_intrinsics);
        cloud.xyz = cloud.xyz(cloud.mask(:), :);
        cloud.norms = renders(view_idx).normals;
        cloud.scale = estimate_size(cloud.xyz);
        cloud.scaled_xyz = cloud.xyz / cloud.scale;
        
        segment.cloud = cloud;
  %%      
        % computing the features for the segment
        segment.features = compute_segment_features(segment.cloud, params);

        segment.transforms = compute_segment_transforms(segment.cloud);

        segment.transforms.rotate_to_plane = eye(4);
        segment.seg_index = 1;

        
        % for this region, propose matching shapes (+transforms) from the database
        [segment_matches, these_matches] = ...
            propose_matches(segment, model, params, paths);

        % now viewing this match
        yaml_matches = convert_matches_to_yaml(these_matches);

        clf
        plot3d(segment.cloud.xyz, 'y');
        hold on
        xyz = plot_matches_3d(yaml_matches);
        hold off
        view(122, 90)
    end
   
    disp(['Done ' num2str(ii)])
end



%{

    model.idx = params.test_dataset.models_to_use(ii);
    model.name = params.model_filelist{model.idx};
    load(sprintf(paths.basis_models.combined_file, model.name), 'renders')
    
    for view_idx = params.test_dataset.views_to_use
        cloud = renders(view_idx);
        cloud.xyz = reproject_depth(cloud.depth, params.half_intrinsics);
        cloud.xyz(isnan(cloud.xyz(:, 1)), :) = [];
        
        % segmenting the view
        [cloud.segment.idxs, cloud.segment.probabilities, cloud.segment.rotate_to_plane] = ...
            segment_soup_3d(cloud, params.segment_soup);
    
    end
    
    disp(['Doing model number ' num2str(cloud.idx)])
    
    
    % extracting the segments
    for seg_idx = 1:size(cloud.segment.idxs, 2);

        cloud.segments{seg_idx} = ...
            extract_segment(cloud, cloud.segment.idxs(:, seg_idx), params);
        cloud.segments{seg_idx}.seg_index = seg_idx;
        cloud.segments{seg_idx} = rmfield(cloud.segments{seg_idx}, 'cloud');

        done(seg_idx, size(cloud.segment.idxs, 2));
    end
    
%}


