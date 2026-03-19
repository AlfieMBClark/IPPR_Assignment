function RubberStain(input_image, showFigures)
    if nargin < 2, showFigures = true; end
    try
        % Preprocessing w shared utilities
        gray_image = GloveDetectionUtils.convertToGrayscale(input_image);
        filtered_image = GloveDetectionUtils.applyMedianFilter(gray_image, [3, 3]);

        % Thresholding
        threshold_value = 0.4; 
        binary_image = imbinarize(filtered_image, threshold_value);
        inverted_binary_image = ~binary_image;
        SE0 = strel('disk', 3);
        inverted_binary_image = imopen(inverted_binary_image, SE0);

        % Fill holes binary img
        filled_image = imfill(inverted_binary_image, 'holes');

        % Glove masky
        RNS_glove_mask = GloveDetectionUtils.extractGloveMask(filled_image, 1);

        neighborhood = ones(5);
        structuring_element = strel(neighborhood);
        RNS_defect_mask = imopen(inverted_binary_image, structuring_element);

        %Stain candidates
        glove_interior = imerode(RNS_glove_mask, strel('disk', 2));
        cavity_candidates = RNS_glove_mask & ~inverted_binary_image;
        cavity_candidates = cavity_candidates & glove_interior;
        cavity_candidates = bwareaopen(cavity_candidates, 6);

        %colour validation
        hsv_img = rgb2hsv(input_image);
        H = hsv_img(:,:,1); S = hsv_img(:,:,2); V = hsv_img(:,:,3);

        %detect skin to reject holes
        skin_mask = ((H < 0.12) | (H > 0.92)) & (S > 0.16) & (S < 0.70) & (V > 0.18) & (V < 0.90);
        skin_mask = medfilt2(skin_mask, [5 5]);
        skin_mask = bwareaopen(skin_mask & glove_interior, 80);

        %stains are white-ish - I used sun screen :)
        white_mask = (S < 0.35) & (V > 0.62) & glove_interior;
        white_mask = medfilt2(white_mask, [3 3]);

        candidate_mask = cavity_candidates & white_mask;

        %suppress skin holes + edge
        cc = bwconncomp(candidate_mask);
        RNS_stain_mask = false(size(candidate_mask));
        glove_boundary_band = imdilate(bwperim(RNS_glove_mask), strel('disk', 4));
        for k = 1:cc.NumObjects
            comp = false(size(candidate_mask));
            comp(cc.PixelIdxList{k}) = true;
            comp = imfill(comp, 'holes');
            comp_area = nnz(comp);
            touches_boundary = any(comp(:) & glove_boundary_band(:));
            skin_overlap = nnz(comp & skin_mask) / max(comp_area, 1);
            mean_s = mean(S(comp));
            mean_v = mean(V(comp));
            %reject skin and border strips.
            keep_comp = (comp_area >= 6) && (mean_v > 0.55) && (mean_s < 0.42) ...
                && (skin_overlap < 0.12) && ~(touches_boundary && comp_area > 180);
            if keep_comp
                RNS_stain_mask = RNS_stain_mask | comp;
            end
        end

        % Detect and filter defects
        min_stain_area = 6;
        [large_stains, RNS_stain_mask_filtered] = GloveDetectionUtils.detectAndFilterDefects(RNS_stain_mask, min_stain_area);
        % Save filtered mask
        RNS_stain_mask = RNS_stain_mask_filtered;
        save(fullfile(pwd, 'RNpic.mat'), 'RNS_glove_mask', 'RNS_defect_mask', 'RNS_stain_mask', 'skin_mask');
        save(fullfile(pwd, 'RNvariables.mat'), 'large_stains');
        if showFigures
            displayProcessingSteps(input_image, gray_image, filtered_image, binary_image, inverted_binary_image, filled_image, RNS_glove_mask, RNS_defect_mask, RNS_stain_mask, skin_mask);
            GloveDetectionUtils.displayDefectResults(input_image, large_stains, RNS_stain_mask_filtered, 'Stain');
        end

    catch ME
        disp(ME.message);
    end
end

function displayProcessingSteps(original_img, gray_img, filtered_img, binary_img, inverted_binary, filled_img, glove_mask, defect_mask, stain_mask, skin_mask)
    h = figure('Name', 'Processing Steps - Rubber Nitrile Stain Detection', 'NumberTitle', 'off', 'Position', [100 100 1200 700]);
    try
        subplot(3,4,1); imshow(original_img); title('1. Original RGB');
        subplot(3,4,2); imshow(gray_img); colormap(gca, gray); title('2. Grayscale');
        subplot(3,4,3); imshow(filtered_img); colormap(gca, gray); title('3. Median Filtered');
        subplot(3,4,4); imshow(binary_img); title('4. Binarized');
        subplot(3,4,5); imshow(inverted_binary); title('5. Inverted Binary');
        subplot(3,4,6); imshow(filled_img); title('6. Filled Image');
        subplot(3,4,7); imshow(glove_mask); title('7. Glove Mask');
        subplot(3,4,8); imshow(defect_mask); title('8. Defect Mask (opened)');
        subplot(3,4,9); imshow(skin_mask); title('9. Skin Mask (excluded) ★');
        subplot(3,4,10); imshow(stain_mask); title('10. Stain Mask (no skin)');
        subplot(3,4,11); imshow(labeloverlay(original_img, stain_mask, 'Transparency', 0.6)); title('11. Stain Overlay');
        subplot(3,4,12); imshow(labeloverlay(original_img, glove_mask, 'Colormap', 'spring', 'Transparency', 0.3)); title('12. Glove Mask Overlay');
        drawnow;
    catch
        if ishandle(h), close(h); end
    end
end