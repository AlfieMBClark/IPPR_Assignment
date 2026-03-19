function RubberHole(image, showFigures)
    if nargin < 2, showFigures = true; end
    try
        %shared utilities
        gray_img = GloveDetectionUtils.convertToGrayscale(image);
        filtered_image = GloveDetectionUtils.applyMedianFilter(gray_img, [3, 3]);
        hsv_img = rgb2hsv(image);
        H = hsv_img(:,:,1); S = hsv_img(:,:,2); V = hsv_img(:,:,3);
 
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

        % Conditional glare mode:
        % Keep original pipeline for normal images, but if reflection is high on glove,
        % switch to reflection-suppressed adaptive thresholding.
        glove_interior_for_glare = imerode(filledImg, strel('disk', 4));
        % High-glare trigger uses bright coverage in binarized glove plus a
        % specular fallback for concentrated reflection patches.
        glare_like_pixels = bwImg & glove_interior_for_glare;
        bright_ratio = nnz(glare_like_pixels) / max(nnz(glove_interior_for_glare), 1);
        specular_like_pixels = (S < 0.25) & (V > 0.72) & glove_interior_for_glare;
        specular_ratio = nnz(specular_like_pixels) / max(nnz(glove_interior_for_glare), 1);
        high_glare_mode = (bright_ratio > 0.25) || (specular_ratio > 0.06);
        glare_ratio = bright_ratio;
        if high_glare_mode
            fprintf('RubberHole mode: HIGH GLARE ON (bright ratio=%.4f [>0.25] OR specular ratio=%.4f [>0.06])\n', bright_ratio, specular_ratio);
        else
            fprintf('RubberHole mode: High glare OFF (bright ratio=%.4f [<=0.25], specular ratio=%.4f [<=0.06])\n', bright_ratio, specular_ratio);
        end
        high_glare_std_enclosed = false(size(filledImg));
        high_glare_bright_on_glove = false(size(filledImg));
        high_glare_candidates = false(size(filledImg));
        high_glare_final = false(size(filledImg));
        if high_glare_mode
            filtered_norm = im2double(filtered_image);
            local_med = medfilt2(filtered_norm, [9 9]);
            filtered_for_bin = filtered_norm;
            filtered_for_bin(glare_like_pixels) = local_med(glare_like_pixels);

            local_T = adaptthresh(filtered_for_bin, 0.50, 'NeighborhoodSize', [61 61]);
            bwImg = imbinarize(filtered_for_bin, local_T);
            inverted_bwImg = ~bwImg;

            glove_seed = bwareaopen(inverted_bwImg, 200);
            glove_seed = imclose(glove_seed, strel('disk', 4));
            glove_seed = imdilate(glove_seed, strel('disk', 1));
            filledImg = imfill(glove_seed, 'holes');
            filledImg = bwareafilt(filledImg, 1);
            filledImg = imerode(filledImg, strel('disk', 1));
            filledImg = imdilate(filledImg, strel('disk', 2));
        end
 
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

        % High-glare alternative: derive candidates from enclosed local std-dev regions
        % that overlap bright (white) binarized glove pixels AND skin-like areas.
        if high_glare_mode
            std_vals = std_normalized(glove_interior_for_glare);
            std_thr = mean(std_vals) + 0.65 * std(std_vals);
            high_glare_std_enclosed = (std_normalized > std_thr) & glove_interior_for_glare;
            high_glare_std_enclosed = imclose(high_glare_std_enclosed, strel('disk', 2));
            high_glare_std_enclosed = imfill(high_glare_std_enclosed, 'holes');
            high_glare_std_enclosed = bwareaopen(high_glare_std_enclosed, 40);
            high_glare_std_enclosed = imclearborder(high_glare_std_enclosed);

            high_glare_bright_on_glove = bwImg & glove_interior_for_glare;
            high_glare_bright_on_glove = imopen(high_glare_bright_on_glove, strel('disk', 1));
            high_glare_bright_on_glove = bwareaopen(high_glare_bright_on_glove, 20);

            % Gate candidates with skin-like color regions
            skin_hue_like = (H < 0.12) | (H > 0.92);
            skin_sat_like = (S > 0.16) & (S < 0.70);
            skin_val_like = (V > 0.18) & (V < 0.90);
            skin_like_candidate = skin_hue_like & skin_sat_like & skin_val_like & glove_interior_for_glare;

            % Combine: Std ∩ White ∩ Skin
            high_glare_candidates = high_glare_std_enclosed & imdilate(high_glare_bright_on_glove, strel('disk', 1)) & imdilate(skin_like_candidate, strel('disk', 2));
            high_glare_candidates = imclose(high_glare_candidates, strel('disk', 2));
            high_glare_candidates = imfill(high_glare_candidates, 'holes');
            high_glare_candidates = bwareaopen(high_glare_candidates, 50);

            % Use this alternative candidate source for high-glare images.
            combined_holes = high_glare_candidates;
            intensity_holes = high_glare_candidates;
        end
 
        %SKIN COLOUR
        glove_interior = imerode(filledImg, strel('disk', 4));

        % High-glare-only: use local std-dev to reject wrinkle/crease structures.
        if high_glare_mode
            std_vals = std_normalized(glove_interior);
            std_mean = mean(std_vals);
            std_sigma = std(std_vals);
            wrinkle_like_mask = (std_normalized > (std_mean + 0.75 * std_sigma)) & glove_interior;
            wrinkle_like_mask = imopen(wrinkle_like_mask, strel('disk', 1));
            wrinkle_like_mask = bwareaopen(wrinkle_like_mask, 20);
            combined_holes = combined_holes & ~imdilate(wrinkle_like_mask, strel('disk', 1));
            combined_holes = bwareaopen(combined_holes, 15);
        else
            std_mean = 0;
            std_sigma = 1;
        end

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
 
        % For high glare mode, use high_glare_candidates directly as final result
        if high_glare_mode
            RNH_hole = high_glare_candidates;
            high_glare_final = RNH_hole;
        else
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

                % Additional sunscreen-stain rejection
                comp_mean_s = mean(S(comp_filled));
                comp_mean_v = mean(V(comp_filled));
                bright_low_sat_ratio = nnz((S < 0.25) & (V > 0.68) & comp_filled) / max(comp_area, 1);
                is_white_stain_component = (comp_mean_s < 0.24 && comp_mean_v > 0.60) || (bright_low_sat_ratio > 0.55);

                if (passes_skin_gate || interior_contrast_hole) && ~looks_like_missing_finger && ~boundary_strip_like && ~tiny_boundary_gap && ~is_white_stain_component
                    RNH_hole = RNH_hole | comp_filled;
                end
            end
        end
        if showFigures
            displayProcessingSteps(image, gray_img, filtered_image, entropy_normalized, std_normalized, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, RNH_hole, skin_mask_raw, high_glare_mode, glare_ratio);
            if high_glare_mode
                displayHighGlareSteps(image, std_normalized, high_glare_std_enclosed, high_glare_bright_on_glove, high_glare_candidates, high_glare_final);
            end
        end
        save(fullfile(pwd, 'RNpic.mat'), 'RNH_filledMask',"RNH_DefectMask","RNH_hole", 'high_glare_mode', 'glare_ratio', 'high_glare_std_enclosed', 'high_glare_bright_on_glove', 'high_glare_candidates', 'high_glare_final');
 
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
 
function displayProcessingSteps(original_img, gray_img, filtered_image, entropy_norm, std_norm, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, final_hole_mask, skin_mask, high_glare_mode, glare_ratio)
    if high_glare_mode
        mode_label = 'HIGH GLARE ON';
    else
        mode_label = 'High glare OFF';
    end
    fig_title = sprintf('Processing Steps - Rubber Nitrile Hole Detection | Mode: %s | bright ratio: %.4f', mode_label, glare_ratio);
    h = figure('Name', fig_title, 'NumberTitle', 'off', 'Position', [100 100 1400 900]);
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

function displayHighGlareSteps(original_img, std_norm, std_enclosed, bright_on_glove, glare_candidates, glare_final)
    h = figure('Name', 'High Glare Alternative Steps - Rubber Hole', 'NumberTitle', 'off', 'Position', [120 120 1400 360]);
    try
        subplot(1,5,1); imshow(std_norm); colormap(gca, gray); title('1. Local Std Dev (norm)');
        subplot(1,5,2); imshow(std_enclosed); title('2. Enclosed Std Regions');
        subplot(1,5,3); imshow(bright_on_glove); title('3. Binarized White on Glove');
        subplot(1,5,4); imshow(glare_candidates); title('4. Std ∩ White Overlap');
        subplot(1,5,5); imshow(labeloverlay(original_img, glare_final, 'Transparency', 0.5)); title('5. High-Glare Final Output');
        drawnow;
    catch
        if ishandle(h), close(h); end
    end
end