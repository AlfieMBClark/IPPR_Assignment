function RubberNitrileMissingFingerDetector(input_img)
    try
        % Convert image to grayscale
        gray_img = rgb2gray(input_img);

        % Apply Gaussian filter for smoothing
        blurred_img = imgaussfilt(gray_img, 4);

        % ===== HSV COLOR ANALYSIS =====
        % Convert to HSV for better color discrimination
        hsv_img = rgb2hsv(input_img);
        H = hsv_img(:,:,1); % Hue
        S = hsv_img(:,:,2); % Saturation
        V = hsv_img(:,:,3); % Value (brightness)
        
        % Detect BLACK GLOVE material (low Value/brightness, low Saturation)
        black_mask = (V < 0.3) & (S < 0.5);
        black_mask = medfilt2(black_mask, [5 5]); % Remove noise
        black_mask = imfill(black_mask, 'holes');
        black_mask = bwareaopen(black_mask, 500);
        black_mask = bwareafilt(black_mask, 1); % Get largest component
        
        % Detect SKIN/PINK regions (higher saturation, specific hue range for brown/pink)
        % Pink/brown skin typically has hue in range [0-0.1] or [0.9-1.0] (red-ish)
        % Tightened parameters to reduce false positives
        skin_mask = ((H < 0.12) | (H > 0.92)) & (S > 0.15) & (S < 0.6) & (V > 0.3) & (V < 0.85);
        skin_mask = medfilt2(skin_mask, [5 5]);
        skin_mask = bwareaopen(skin_mask, 500); % Increased minimum area
        
        % Further refine: remove isolated small regions
        skin_mask = bwmorph(skin_mask, 'close', 2);
        skin_mask = imfill(skin_mask, 'holes');
        
        % Detect BACKGROUND (low saturation, medium-high value for grey)
        % More strict background detection
        background_mask = (S < 0.15) & (V > 0.5) & (V < 0.95);
        background_mask = imopen(background_mask, strel('disk', 3));
        background_mask = bwareaopen(background_mask, 5000); % Larger threshold for background
        background_mask = bwareafilt(background_mask, 1); % Get largest background region
        
        % Create FOREGROUND mask using convex hull of black glove
        % This creates a tight boundary around the glove shape
        foreground_base = black_mask | skin_mask; % Include both glove and detected skin
        foreground_mask = bwconvhull(foreground_base);
        
        % Expand moderately to include edge areas
        SE_foreground = strel('disk', 15); % Moderate expansion
        foreground_mask = imdilate(foreground_mask, SE_foreground);
        
        % Remove confirmed background
        foreground_mask = foreground_mask & ~background_mask;
        
        % Clean up
        foreground_mask = imfill(foreground_mask, 'holes');
        foreground_mask = imclose(foreground_mask, strel('disk', 5));
        foreground_mask = bwareafilt(foreground_mask, 1);
        
        % Threshold image to create a binary mask for the glove area
        complete_mask = imbinarize(blurred_img, 0.65);
        RNMF_defect_mask = imbinarize(blurred_img, 0.40);

        % ===== EDGE DETECTION =====
        edges = edge(blurred_img, 'Canny');
        SE_edge = strel('disk', 2);
        edges_dilated = imdilate(edges, SE_edge);
        
        % ===== CREATE EXPECTED GLOVE SHAPE =====
        % Use convex hull of black glove to get expected complete shape
        expected_glove_shape = bwconvhull(black_mask);
        SE_expand = strel('disk', 15);
        expected_glove_shape = imdilate(expected_glove_shape, SE_expand);
        expected_glove_shape = imfill(expected_glove_shape, 'holes');

        % Invert the glove mask
        complete_mask = ~complete_mask;
        RNMF_defect_mask = ~RNMF_defect_mask;

        % Fill any holes in the binary mask for the glove area
        completed_filled_mask = imfill(complete_mask, 'holes');

        % Apply morphological opening to remove noise from the glove mask
        structuring_element_glove = strel('disk', 10);
        complete_opened_mask = imopen(completed_filled_mask, structuring_element_glove);

        % Remove small objects from the glove mask
        min_glove_area_threshold = 1000; % Adjust as needed
        RNMF_glove_filtered_mask = bwareaopen(complete_opened_mask, min_glove_area_threshold);

        SE1 = strel('disk', 15); % Adjust the size as needed

        % Erode the thresholded image
        RNMF_glove_filtered_mask = imerode(RNMF_glove_filtered_mask, SE1);

        nhood = ones(5); 
        open = strel(nhood);
        RNMF_defect_mask = imopen(RNMF_defect_mask, open);

        % ===== DETECT MISSING FINGERS =====
        % Direct approach: Skin detected within foreground = Missing finger
        % Only count skin if it appears in the foreground (where glove should be)
        RN_missingfinger = skin_mask & foreground_mask;
        
        % Refine: remove areas with strong edges (boundaries/artifacts)
        RN_missingfinger = RN_missingfinger & ~edges_dilated;
        
        % Clean up small noise
        RN_missingfinger = bwareaopen(RN_missingfinger, 200);
        
        % Dilate to merge nearby detections (combine close fragments)
        SE_merge = strel('disk', 8);
        RN_missingfinger = imdilate(RN_missingfinger, SE_merge);
        
        % Fill holes created during dilation
        RN_missingfinger = imfill(RN_missingfinger, 'holes');
        
        % Apply closing to smooth boundaries
        SE_close = strel('disk', 5);
        RN_missingfinger = imclose(RN_missingfinger, SE_close);
        
        % Light erosion to refine edges
        SE3 = strel('disk', 2);
        RN_missingfinger = imerode(RN_missingfinger, SE3);
        
        % Final fill
        RN_missingfinger = imfill(RN_missingfinger, 'holes');
        
        save(fullfile(pwd, 'RNpic.mat'),'black_mask', 'skin_mask', 'background_mask', 'foreground_mask', 'RN_missingfinger');

        % Find the connected components in the stitch mask
        finger_cc = bwconncomp(RN_missingfinger);

        % Calculate the properties of connected components
        finger_props = regionprops(finger_cc, 'BoundingBox', 'Area');

        % Threshold for minimum area of detected stitch (adjust as needed)
        min_finger_area = 2000; % Reduced threshold for more sensitive detection

        % Filter out small stitches based on area threshold
        LMissingFinger = finger_props([finger_props.Area] > min_finger_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'LMissingFinger');

        % Display all intermediate processing steps
        displayProcessingSteps(input_img, gray_img, blurred_img, hsv_img, black_mask, skin_mask, background_mask, foreground_mask, edges, edges_dilated, RN_missingfinger);

        % Display final results
        displayResults(input_img, LMissingFinger, RN_missingfinger);

    catch ME
        disp(ME.message);
    end
end

function displayResults(original_img, missing_fingers, finger_mask)
    % Display the detection results
    figure('Name', 'Rubber Nitrile Missing Finger Detection Results', 'NumberTitle', 'off');
    
    % Show original image with bounding boxes
    subplot(1, 2, 1);
    imshow(original_img);
    title(sprintf('Detected Missing Fingers: %d', length(missing_fingers)));
    hold on;
    
    % Draw bounding boxes around detected missing fingers
    for i = 1:length(missing_fingers)
        bbox = missing_fingers(i).BoundingBox;
        rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
        
        % Add label with finger number
        text(bbox(1), bbox(2)-5, sprintf('Missing Finger %d', i), ...
             'Color', 'red', 'FontSize', 10, 'FontWeight', 'bold', ...
             'BackgroundColor', 'white');
    end
    hold off;
    
    % Show mask overlay
    subplot(1, 2, 2);
    imshow(labeloverlay(original_img, finger_mask, 'Transparency', 0.5));
    title('Missing Finger Mask Overlay');
    
    % Print summary
    fprintf('\n=== MISSING FINGER DETECTION SUMMARY ===\n');
    fprintf('Total missing fingers detected: %d\n', length(missing_fingers));
    if ~isempty(missing_fingers)
        fprintf('\nMissing Finger Details:\n');
        for i = 1:length(missing_fingers)
            fprintf('  Missing Finger %d - Area: %.0f pixels\n', i, missing_fingers(i).Area);
        end
    else
        fprintf('No missing fingers detected - glove appears complete.\n');
    end
    fprintf('========================================\n\n');
end

function displayProcessingSteps(original_img, gray_img, blurred_img, hsv_img, black_mask, skin_mask, background_mask, foreground_mask, edges, edges_dilated, final_mask)
    % Display step-by-step intermediate outputs in a tiled figure
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
        % If any visualization step fails, close figure and continue
        if ishandle(h), close(h); end
    end
end