function RubberHole(image, showFigures)
    if nargin < 2, showFigures = true; end
    try
        %shared utilities
        gray_img = GloveDetectionUtils.convertToGrayscale(image);
        filtered_image = GloveDetectionUtils.applyMedianFilter(gray_img, [3, 3]);
 
        % TEXTURE
        %entropy
        entropy_img = entropyfilt(filtered_image, ones(9));
        entropy_normalized = mat2gray(entropy_img);
        
        %standard dev
        std_img = stdfilt(filtered_image, ones(9));
        std_normalized = mat2gray(std_img);
        
        % Comb texture features - holes have high entropy and low std dev
        texture_score = entropy_normalized .* (1 - std_normalized);
        texture_mask = texture_score > 0.45; 
        
        %INTENSITY
        bwImg = imbinarize(filtered_image, 0.38);
        inverted_bwImg = ~bwImg;
 
        %FILL GLOVE
        % Close edge contour breaks
        glove_seed = bwareaopen(inverted_bwImg, 200);
        glove_seed = imclose(glove_seed, strel('disk', 4));
        glove_seed = imdilate(glove_seed, strel('disk', 1));

        % Fill gove
        filledImg = imfill(glove_seed, 'holes');
        filledImg = bwareafilt(filledImg, 1);
        filledImg = imerode(filledImg, strel('disk', 1));

        % Fallback path: if thresholding is too weak for this image, derive a mask
        % from local-std texture edges and keep only the largest region.
        if ~any(filledImg(:))
            std_thresh = std_normalized > 0.08;
            std_thresh = bwareaopen(std_thresh, 200);
            std_thresh = imdilate(std_thresh, strel('disk', 2));
            std_candidate = imfill(std_thresh, 'holes');
            filledImg = bwareafilt(std_candidate, 1);
        end

        filledImg = imdilate(filledImg, strel('disk', 2)); % recover edge pixels
 
        % Filled glove mask
        RNH_filledMask = filledImg;
 
        %DEFECT MASK
        nhood = ones(5);
        open = strel(nhood);
        RNH_DefectMask = imopen(inverted_bwImg, open);
        numIterations = 2;
        for i = 1:numIterations
            RNH_DefectMask = imopen(RNH_DefectMask, open);
        end
 
        %HOLE CANDIDATES
        cavity_holes = filledImg & ~inverted_bwImg;
        cavity_holes = cavity_holes & imerode(filledImg, strel('disk', 2));
        cavity_holes = bwareaopen(cavity_holes, 12);
        intensity_holes = cavity_holes;

        % Texture cue is used only near potnetial hole
        texture_holes = texture_mask & imdilate(cavity_holes, strel('disk', 2));
        texture_holes = bwareaopen(texture_holes, 12);
        combined_holes = cavity_holes | texture_holes;
 
        %SKIN COLOUR
        hsv_img = rgb2hsv(image);
        H = hsv_img(:,:,1); S = hsv_img(:,:,2); V = hsv_img(:,:,3);
        glove_interior = imerode(filledImg, strel('disk', 4));
        skin_hue = (H < 0.12) | (H > 0.92);
        skin_sat = (S > 0.16) & (S < 0.70);
        skin_val = (V > 0.18) & (V < 0.90);
        %Filter OUt stain
        white_stain_like = (S < 0.22) & (V > 0.68);
        skin_mask_raw = skin_hue & skin_sat & skin_val & ~white_stain_like;
        skin_mask_raw = skin_mask_raw & glove_interior;
        skin_mask = medfilt2(skin_mask_raw, [5 5]);
        skin_mask = bwareaopen(skin_mask, 50);
        skin_mask = imclearborder(skin_mask);
        skin_mask = imdilate(skin_mask, strel('disk', 3));
 
        %fill each candidate hole, keep if it overlaps skin mask.
        % Reject potential missing finger
        cc_holes = bwconncomp(combined_holes);
        RNH_hole = false(size(intensity_holes));
        glove_area = nnz(filledImg);
        glove_boundary_band = imdilate(bwperim(filledImg), strel('disk', 5));
        skin_gate_mask = imdilate(skin_mask, strel('disk', 2));
        gray_norm = im2double(gray_img);
        for k = 1:cc_holes.NumObjects
            comp = false(size(intensity_holes));
            comp(cc_holes.PixelIdxList{k}) = true;
            comp_filled = imfill(comp, 'holes');

            % Missing finger: if candidate touches glove border and is large.
            touches_boundary = any(comp_filled(:) & glove_boundary_band(:));
            area_ratio = nnz(comp_filled) / max(glove_area, 1);
            comp_area = nnz(comp_filled);
            looks_like_missing_finger = touches_boundary && (area_ratio > 0.02);

            overlap_ratio = nnz(comp_filled & skin_gate_mask) / max(nnz(comp_filled), 1);
            comp_props = regionprops(comp_filled, 'BoundingBox', 'Area');
            bb = comp_props(1).BoundingBox;
            bb_aspect = max(bb(3), bb(4)) / max(min(bb(3), bb(4)), 1);
            bb_extent = comp_props(1).Area / max(bb(3) * bb(4), 1);

            % Interior holes less stict
            if touches_boundary
                passes_skin_gate = overlap_ratio > 0.28;
            else
                passes_skin_gate = overlap_ratio > 0.05;
            end

            ring = imdilate(comp_filled, strel('disk', 4)) & ~comp_filled & filledImg;
            if any(ring(:))
                hole_mean = mean(gray_norm(comp_filled));
                ring_mean = mean(gray_norm(ring));
                contrast_ok = (hole_mean - ring_mean) > 0.08;
            else
                contrast_ok = false;
            end

            % Reject boundary strips from glove edges.
            boundary_strip_like = touches_boundary && (bb_aspect > 3.0 || bb_extent < 0.32);
            tiny_boundary_gap = touches_boundary && (comp_area < 90);
            interior_contrast_hole = ~touches_boundary && contrast_ok;

            % Additional sunscreen-stain rejectio
            comp_mean_s = mean(S(comp_filled));
            comp_mean_v = mean(V(comp_filled));
            bright_low_sat_ratio = nnz((S < 0.25) & (V > 0.68) & comp_filled) / max(comp_area, 1);
            is_white_stain_component = (comp_mean_s < 0.24 && comp_mean_v > 0.60) || (bright_low_sat_ratio > 0.55);

            if (passes_skin_gate || interior_contrast_hole) && ~looks_like_missing_finger && ~boundary_strip_like && ~tiny_boundary_gap && ~is_white_stain_component
                RNH_hole = RNH_hole | comp_filled;
            end
        end
        if showFigures
            displayProcessingSteps(image, gray_img, filtered_image, entropy_normalized, std_normalized, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, RNH_hole, skin_mask_raw);
        end
        save(fullfile(pwd, 'RNpic.mat'), 'RNH_filledMask',"RNH_DefectMask","RNH_hole");
 
        % Detect and filter defects
        min_hole_area = 60;
        [large_holes, ~] = GloveDetectionUtils.detectAndFilterDefects(RNH_hole, min_hole_area);
 
        save(fullfile(pwd, 'RNvariables.mat'), 'large_holes');
 
        % Disp results
        if showFigures
            GloveDetectionUtils.displayDefectResults(image, large_holes, RNH_hole, 'Hole');
        end
 
    catch ME
        disp(ME.message);
    end
end
 
function displayProcessingSteps(original_img, gray_img, filtered_image, entropy_norm, std_norm, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, final_hole_mask, skin_mask)
    h = figure('Name', 'Processing Steps - Rubber Nitrile Hole Detection', 'NumberTitle', 'off', 'Position', [100 100 1400 900]);
    try
        subplot(4,4,1); imshow(original_img); title('Original RGB');
        subplot(4,4,2); imshow(gray_img); colormap(gca, gray); title('Grayscale');
        subplot(4,4,3); imshow(filtered_image); colormap(gca, gray); title('Median Filtered');
        subplot(4,4,4); imshow(entropy_norm); colormap(gca, gray); title('Local Entropy (norm)');
 
        subplot(4,4,5); imshow(std_norm); colormap(gca, gray); title('Local Std Dev (norm)');
        subplot(4,4,6); imagesc(texture_score); axis image off; colormap(gca, hot); title('Texture Score');
        subplot(4,4,7); imshow(texture_mask); title('Texture Mask (binary)');
        subplot(4,4,8); imshow(bwImg); title('Binarized (imbinarize)');
 
        subplot(4,4,9); imshow(inverted_bwImg); title('Inverted Binary');
        subplot(4,4,10); imshow(filledImg); title('Filled Image');
        subplot(4,4,11); imshow(RNH_filledMask); title('Filled Glove Mask');
        subplot(4,4,12); imshow(RNH_DefectMask); title('Defect Mask (opened)');
 
        subplot(4,4,13); imshow(intensity_holes); title('Intensity-based Holes');
        subplot(4,4,14); imshow(combined_holes); title('Combined Intensity & Texture');
        subplot(4,4,15); imshow(skin_mask); title('Skin Mask (HSV raw) ★');
        subplot(4,4,16); imshow(labeloverlay(original_img, final_hole_mask, 'Transparency', 0.5)); title('Final: Skin-confirmed Holes');
 
        drawnow;
    catch
        if ishandle(h), close(h); end
    end
end