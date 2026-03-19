function RubberFinger(input_img, showFigures)
    if nargin < 2, showFigures = true; end
    try
        %hared utilities
        gray_img = GloveDetectionUtils.convertToGrayscale(input_img);
        
        %lighting normalization
        gray_img = adapthisteq(gray_img, 'NumTiles', [8 8], 'ClipLimit', 0.02);
        
        blurred_img = GloveDetectionUtils.applyGaussianFilter(gray_img, 4);

        %HSV
        % Conve to HSV
        hsv_img = rgb2hsv(input_img);
        H = hsv_img(:,:,1); 
        S = hsv_img(:,:,2); 
        V = hsv_img(:,:,3); 
        
        % Detect Glove
        black_mask = (V < 0.38) & (S < 0.60);
        black_mask = medfilt2(black_mask, [5 5]); % Rmv noise
        black_mask = imfill(black_mask, 'holes');
        black_mask = bwareaopen(black_mask, 500);
        black_mask = bwareafilt(black_mask, 1); % Get largest
        
        %Glove Type
        non_background_mask = ~((S < 0.15) & (V > 0.5) & (V < 0.95));
        non_background_pixels = max(1, nnz(non_background_mask));
        black_coverage = nnz(black_mask & non_background_mask) / non_background_pixels;
        if black_coverage < 0.18
            RN_missingfinger = false(size(V));
            LMissingFinger = struct('BoundingBox', {}, 'Area', {});
            background_mask = ~non_background_mask;
            foreground_mask = false(size(V));
            skin_mask = false(size(V));
            save(fullfile(pwd, 'RNpic.mat'), 'black_mask', 'skin_mask', 'background_mask', 'foreground_mask', 'RN_missingfinger');
            save(fullfile(pwd, 'RNvariables.mat'), 'LMissingFinger');
            if showFigures
                figure('Name', 'Rubber Nitrile Missing Finger Detection', 'NumberTitle', 'off');
                imshow(input_img);
                title(sprintf('Defect not Detected for this type of glove'));
            end
            return;
        end
        
        % Detect skin
        skin_hue = (H < 0.12) | (H > 0.92);
        skin_mask_main = skin_hue & (S > 0.16) & (S < 0.62) & (V > 0.30) & (V < 0.92);
        skin_mask_highlight = skin_hue & (S > 0.08) & (S < 0.35) & (V >= 0.70) & (V < 0.98);
        skin_mask = skin_mask_main | skin_mask_highlight;
        skin_mask = medfilt2(skin_mask, [5 5]);
        skin_mask = bwareaopen(skin_mask, 180);
        
        %remove isolated small regions
        skin_mask = bwmorph(skin_mask, 'close', 2);
        skin_mask = imfill(skin_mask, 'holes');
        
        % Detect background
        background_mask = (S < 0.15) & (V > 0.5) & (V < 0.95);
        background_mask = imopen(background_mask, strel('disk', 3));
        background_mask = bwareaopen(background_mask, 5000); 
        background_mask = bwareafilt(background_mask, 1); 
        
        %Get Forground 
        foreground_base = black_mask | skin_mask; %both glove and detected skin
        foreground_mask = bwconvhull(foreground_base);
        
        % Expand to include edge
        SE_foreground = strel('disk', 15);
        foreground_mask = imdilate(foreground_mask, SE_foreground);
        
        % Remove bg
        foreground_mask = foreground_mask & ~background_mask;
        
        foreground_mask = imfill(foreground_mask, 'holes');
        foreground_mask = imclose(foreground_mask, strel('disk', 5));
        foreground_mask = bwareafilt(foreground_mask, 1);
        
        %glove binary mask
        complete_mask = imbinarize(blurred_img, 0.65);
        RNMF_defect_mask = imbinarize(blurred_img, 0.40);

        %EDGE
        edges = edge(blurred_img, 'Canny');
        SE_edge = strel('disk', 2);
        edges_dilated = imdilate(edges, SE_edge);
        
        %EXpected Glove shape
        expected_glove_shape = bwconvhull(black_mask);
        SE_expand = strel('disk', 15);
        expected_glove_shape = imdilate(expected_glove_shape, SE_expand);
        expected_glove_shape = imfill(expected_glove_shape, 'holes');

        % Inv mask
        complete_mask = ~complete_mask;
        RNMF_defect_mask = ~RNMF_defect_mask;

        % Fill holes in the binary mask glove area
        completed_filled_mask = imfill(complete_mask, 'holes');

        %remove noise frm mask
        structuring_element_glove = strel('disk', 10);
        complete_opened_mask = imopen(completed_filled_mask, structuring_element_glove);

        % Remove small objects
        min_glove_area_threshold = 1000; 
        RNMF_glove_filtered_mask = bwareaopen(complete_opened_mask, min_glove_area_threshold);
        SE1 = strel('disk', 15); 

        % Erode
        RNMF_glove_filtered_mask = imerode(RNMF_glove_filtered_mask, SE1);

        nhood = ones(5); 
        open = strel(nhood);
        RNMF_defect_mask = imopen(RNMF_defect_mask, open);

        %DETECT missing finger
        %skin in glove
        RN_missingfinger = skin_mask & foreground_mask;

        %comparing thickness near each axis
        [fg_y, fg_x] = find(foreground_mask);
        fg_points = [double(fg_x), double(fg_y)];
        fg_center = mean(fg_points, 1);
        fg_cov = cov(fg_points);
        [fg_vecs, fg_vals] = eig(fg_cov);
        [~, major_idx] = max(diag(fg_vals));
        hand_axis = fg_vecs(:, major_idx);

        proj_fg = (fg_points(:,1) - fg_center(1)) * hand_axis(1) + (fg_points(:,2) - fg_center(2)) * hand_axis(2);
        proj_min = min(proj_fg);
        proj_max = max(proj_fg);
        proj_span = max(proj_max - proj_min, eps);

        [yy, xx] = ndgrid(1:size(foreground_mask,1), 1:size(foreground_mask,2));
        proj_map = (double(xx) - fg_center(1)) * hand_axis(1) + (double(yy) - fg_center(2)) * hand_axis(2);
        end_band_frac = 0.12;
        end_band_min = foreground_mask & (proj_map <= (proj_min + end_band_frac * proj_span));
        end_band_max = foreground_mask & (proj_map >= (proj_max - end_band_frac * proj_span));

        fg_dist = bwdist(~foreground_mask);
        thick_min = mean(fg_dist(end_band_min));
        thick_max = mean(fg_dist(end_band_max));
        wrist_is_min_end = thick_min >= thick_max;

        % Reject interior holes - dist
        outer_glove_boundary = bwperim(foreground_mask);
        dist_to_outer_boundary = bwdist(outer_glove_boundary);
        edge_distance_threshold = 18;
        deep_interior_threshold = 26;

        cc_missingfinger = bwconncomp(RN_missingfinger);
        keep_components = false(cc_missingfinger.NumObjects, 1);
        for k = 1:cc_missingfinger.NumObjects
            pixel_idx = cc_missingfinger.PixelIdxList{k};
            min_dist = min(dist_to_outer_boundary(pixel_idx));
            mean_dist = mean(dist_to_outer_boundary(pixel_idx));

            touches_outer_edge_zone = min_dist <= edge_distance_threshold;
            is_deep_interior = mean_dist > deep_interior_threshold;

            comp = false(size(RN_missingfinger));
            comp(pixel_idx) = true;
            comp_props = regionprops(comp, 'Area', 'BoundingBox', 'Centroid');
            comp_area = comp_props(1).Area;
            bb = comp_props(1).BoundingBox;
            bb_aspect = max(bb(3), bb(4)) / max(min(bb(3), bb(4)), 1);
            comp_centroid = comp_props(1).Centroid;
            comp_proj = (comp_centroid(1) - fg_center(1)) * hand_axis(1) + (comp_centroid(2) - fg_center(2)) * hand_axis(2);
            comp_pos_norm = (comp_proj - proj_min) / proj_span;
            if wrist_is_min_end
                wrist_proximity = 1 - comp_pos_norm;
            else
                wrist_proximity = comp_pos_norm;
            end

            % Wrist skin wide + thick
            wrist_like_component = (wrist_proximity > 0.72) && (comp_area > 350) && (bb_aspect < 2.2);

            keep_components(k) = touches_outer_edge_zone && ~is_deep_interior && ~wrist_like_component;
        end

        RN_missingfinger_filtered_components = false(size(RN_missingfinger));
        for k = 1:cc_missingfinger.NumObjects
            if keep_components(k)
                RN_missingfinger_filtered_components(cc_missingfinger.PixelIdxList{k}) = true;
            end
        end
        RN_missingfinger = RN_missingfinger_filtered_components;
        
        % remove strong edge
        RN_missingfinger = RN_missingfinger & ~edges_dilated;
        RN_missingfinger = bwareaopen(RN_missingfinger, 200);
        
        %merge
        SE_merge = strel('disk', 8);
        RN_missingfinger = imdilate(RN_missingfinger, SE_merge);
        % Fill holes
        RN_missingfinger = imfill(RN_missingfinger, 'holes');
        %smooth
        SE_close = strel('disk', 5);
        RN_missingfinger = imclose(RN_missingfinger, SE_close);
        %erosion for edge
        SE3 = strel('disk', 2);
        RN_missingfinger = imerode(RN_missingfinger, SE3);
        % fill
        RN_missingfinger = imfill(RN_missingfinger, 'holes');
        % Detect and filter
        min_finger_area = 2000;
        [LMissingFinger, RN_missingfinger_filtered] = GloveDetectionUtils.detectAndFilterDefects(RN_missingfinger, min_finger_area);

        % Save the filtered mask.
        RN_missingfinger = RN_missingfinger_filtered;
        save(fullfile(pwd, 'RNpic.mat'),'black_mask', 'skin_mask', 'background_mask', 'foreground_mask', 'RN_missingfinger');
        save(fullfile(pwd, 'RNvariables.mat'), 'LMissingFinger');

        if showFigures
            displayProcessingSteps(input_img, gray_img, blurred_img, hsv_img, black_mask, skin_mask, background_mask, foreground_mask, edges, edges_dilated, RN_missingfinger);
            GloveDetectionUtils.displayDefectResults(input_img, LMissingFinger, RN_missingfinger_filtered, 'Missing Finger');
        end

    catch ME
        disp(ME.message);
    end
end

function displayProcessingSteps(original_img, gray_img, blurred_img, hsv_img, black_mask, skin_mask, background_mask, foreground_mask, edges, edges_dilated, final_mask)
    h = figure('Name', 'Processing Steps - Rubber Nitrile Missing Finger Detection', 'NumberTitle', 'off', 'Position', [50 50 1500 750]);
    try
        subplot(3,5,1); imshow(original_img); title('1. Original RGB');
        subplot(3,5,2); imshow(gray_img); colormap(gca, gray); title('2. Grayscale');
        subplot(3,5,3); imshow(hsv_img); title('3. HSV Color Space');
        subplot(3,5,4); imshow(blurred_img); colormap(gca, gray); title('4. Gaussian Blurred');
        subplot(3,5,5); imshow(black_mask); title('5. Black Glove (HSV)');
        subplot(3,5,6); imshow(skin_mask); title('6. Skin Mask (HSV) ★');
        subplot(3,5,7); imshow(background_mask); title('7. Background (HSV)');
        subplot(3,5,8); imshow(foreground_mask); title('8. Foreground ★');
        subplot(3,5,9); imshow(edges); title('9. Edges (Canny)');
        subplot(3,5,10); imshow(skin_mask & foreground_mask); title('10. Skin IN Foreground ★★');
        subplot(3,5,11); imshow(edges_dilated); title('11. Edges Dilated');
        subplot(3,5,12); imshow(final_mask); title('12. Final Missing Finger');
        subplot(3,5,13); imshow(labeloverlay(original_img, foreground_mask, 'Colormap', 'spring', 'Transparency', 0.3)); title('13. Foreground Overlay');
        subplot(3,5,14); imshow(labeloverlay(original_img, skin_mask, 'Colormap', 'hot', 'Transparency', 0.4)); title('14. Skin Overlay');
        subplot(3,5,15); imshow(labeloverlay(original_img, final_mask, 'Transparency', 0.6)); title('15. Final Detection');
        drawnow;
    catch
        if ishandle(h), close(h); end
    end
end