function LatexHole(input_img, showFigures)
    if nargin < 2, showFigures = true; end

    try
        %% GRAYSCALE + MEDIAN FILTER
        gray_img     = GloveDetectionUtils.convertToGrayscale(input_img);
        filtered_img = GloveDetectionUtils.applyMedianFilter(gray_img, [5 5]);

        %% HSV
        hsv_img = rgb2hsv(input_img);
        H = hsv_img(:,:,1);
        S = hsv_img(:,:,2);
        V = hsv_img(:,:,3);

        %% SEPARATE BACKGROUND FROM HAND+GLOVE
        background_mask = (S < 0.15) & (V > 0.55);
        background_mask = bwareaopen(background_mask, 3000);
        background_mask = bwareafilt(background_mask, 1);

        % Hand+glove = everything that is not background
        hand_glove_region = ~background_mask;
        hand_glove_region = bwareaopen(hand_glove_region, 1000);
        hand_glove_region = bwareafilt(hand_glove_region, 1);
        hand_glove_region = imfill(hand_glove_region, 'holes');

        %% EXTRACT THE GLOVE
        is_red_glove = ((H < 0.05) | (H > 0.92)) & ...
                       (S > 0.50) & ...
                       (V > 0.10) & (V < 0.95) & ...
                       hand_glove_region;

        is_red_glove = medfilt2(is_red_glove, [5 5]);
        is_red_glove = bwareaopen(is_red_glove, 500);
        is_red_glove = bwareafilt(is_red_glove, 1);

        % FINDING THE GLOVE
        glove_filled = imfill(is_red_glove, 'holes');
        glove_filled = GloveDetectionUtils.extractGloveMask(glove_filled, 3);
        glove_filled = glove_filled & ~background_mask;

        %% SUBTRACT TO FIND HOLES
        % We then use skin detection to keep only HOLES
        % (holes reveal skin, foreign objects do not)

        glove_gaps = glove_filled & ~is_red_glove;            % everything missing from glove

        %% SKIN DETECTION
        skin_mask = ((H < 0.10) | (H > 0.92)) & ...
                    (S > 0.15) & (S < 0.55) & ...         
                    (V > 0.30) & (V < 0.88);            

        skin_mask = medfilt2(skin_mask, [5 5]);
        skin_mask = bwareaopen(skin_mask, 200);

        % Dilate skin mask for edge blurring around hole boundary
        skin_mask = imdilate(skin_mask, strel('disk', 15));

        % Erode glove filled inward to get strict interior only
        glove_strict_interior = imerode(glove_filled, strel('disk', 20));

        % Hole is the gap in glove interior that overlaps with the skin
        % Gaps at edges/fingertips are excluded by strict interior mask
        hole_mask = glove_gaps & skin_mask & glove_strict_interior;

        %% CLEANING
        hole_mask = bwareaopen(hole_mask, 80);           
        hole_mask = imdilate(hole_mask, strel('disk', 8));   
        hole_mask = imfill(hole_mask, 'holes');
        hole_mask = imclose(hole_mask, strel('disk', 6));
        hole_mask = bwareaopen(hole_mask, 150);               

        %% WRINKLE / SHADOW REJECTION

        cc    = bwconncomp(hole_mask);
        props = regionprops(cc, 'Area', 'Solidity', 'Extent', ...
                                'BoundingBox', 'PixelIdxList');

        hole_mask_clean = false(size(hole_mask));
        for i = 1:numel(props)
            % Reject thin/elongated shapes (wrinkles or fold lines)
            if props(i).Solidity < 0.45,  continue; end
            if props(i).Extent   < 0.25,  continue; end      
            if props(i).Area     < 150,   continue; end      

            hole_mask_clean(props(i).PixelIdxList) = true;
        end

        hole_mask = hole_mask_clean;

        RNH_hole = hole_mask;
        save(fullfile(pwd, 'RNpic.mat'), ...
            'is_red_glove', 'glove_filled', 'glove_gaps', ...
            'skin_mask', 'RNH_hole');

        min_hole_area = 150;
        [large_holes, hole_mask_filtered] = ...
            GloveDetectionUtils.detectAndFilterDefects(RNH_hole, min_hole_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'large_holes');

% DISPLAY
        if showFigures
            figure('Name', 'Hole Detection', ...
                   'NumberTitle', 'off', ...
                   'Position', [50 50 1400 700]);

            subplot(2,4,1); imshow(input_img);                  title('1. Original RGB');
            subplot(2,4,2); imshow(filtered_img);               title('2. Grayscale + Median');
            subplot(2,4,3); imshow(background_mask);            title('3. Background');
            subplot(2,4,4); imshow(hand_glove_region);          title('4. Hand + Glove Region');

            subplot(2,4,5); imshow(is_red_glove);               title('5. Red Glove (actual)');
            subplot(2,4,6); imshow(glove_filled);               title('6. Glove Filled (expected)');
            subplot(2,4,7); imshow(glove_gaps);                 title('7. Gaps (filled - actual)');
            subplot(2,4,8); imshow(glove_strict_interior);      title('8. Strict Interior (no edges)');

            figure('Name', 'Hole Detection Results', ...
                   'NumberTitle', 'off', ...
                   'Position', [50 50 900 400]);

            subplot(1,3,1); imshow(hole_mask_filtered);         title('9. Final Hole Mask');
            subplot(1,3,2); imshow(labeloverlay(input_img, hole_mask_filtered, ...
                            'Colormap', [1 0 0], 'Transparency', 0.45));
                            title('10. Hole Overlay');
            subplot(1,3,3); imshow(input_img); hold on;
            title(sprintf('Holes Detected: %d', numel(large_holes)));
            for i = 1:numel(large_holes)
                bb = large_holes(i).BoundingBox;
                rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 2);
                text(bb(1), bb(2)-6, sprintf('Hole %d', i), ...
                     'Color', 'red', 'FontSize', 9, 'FontWeight', 'bold', ...
                     'BackgroundColor', 'white', 'Margin', 1);
            end
            hold off;
        end

    catch ME
        disp(ME.message);
    end
end