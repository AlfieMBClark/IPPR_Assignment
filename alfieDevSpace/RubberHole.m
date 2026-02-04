function RubberHole(image)
    try
        gray_img = rgb2gray(image);

        % Noise Reduction: Apply Median filtering
        filtered_image = medfilt2(gray_img, [3, 3]);

        % ===== TEXTURE ANALYSIS =====
        % Calculate local entropy (texture irregularity measure)
        entropy_img = entropyfilt(filtered_image, ones(9));
        entropy_normalized = mat2gray(entropy_img);
        
        % Calculate local standard deviation (texture variation)
        std_img = stdfilt(filtered_image, ones(9));
        std_normalized = mat2gray(std_img);
        
        % Combine texture features - holes have high entropy and low std dev
        texture_score = entropy_normalized .* (1 - std_normalized);
        % Use stricter threshold for texture
        texture_mask = texture_score > 0.6;  % Higher threshold = fewer detections
        
        % ===== INTENSITY-BASED ANALYSIS =====
        % Binarize the filtered image (threshold to separate glove from background)
        bwImg = imbinarize(filtered_image, 0.38);
        inverted_bwImg = ~bwImg;

        % Fill any holes in the binary image to get complete glove mask
        filledImg = imfill(inverted_bwImg, 'holes');

        % Get the biggest object (Glove)
        RNH_filledMask = bwareafilt(filledImg, 1);
        SE = strel('disk', 1); 
        RNH_filledMask = imdilate(RNH_filledMask, SE);

        % Create defect mask with morphological opening
        nhood = ones(5); 
        open = strel(nhood);
        RNH_DefectMask = imopen(inverted_bwImg, open);

        % Perform multiple iterations of morphological opening to remove holes
        numIterations = 10; 
        for i = 1:numIterations
            RNH_DefectMask = imopen(RNH_DefectMask, open);
        end

        % Subtract to find holes (filled glove - glove without holes = holes)
        intensity_holes = imsubtract(RNH_filledMask, RNH_DefectMask);
        intensity_holes = im2bw(intensity_holes);
        
        % ===== COMBINE INTENSITY AND TEXTURE =====
        % Use AND logic: must be detected by BOTH intensity AND texture
        combined_holes = intensity_holes & (texture_mask & RNH_filledMask);
        
        % Clean up combined result
        SE1 = strel('square', 5);
        RNH_hole = imopen(combined_holes, SE1);
        
        % Remove very small noise
        RNH_hole = bwareaopen(RNH_hole, 100);
        
        % Dilate significantly to merge nearby fragments and expand regions
        SE_merge = strel('disk', 15);
        RNH_hole = imdilate(RNH_hole, SE_merge);
        
        % Fill any internal holes to create solid regions
        RNH_hole = imfill(RNH_hole, 'holes');
        
        % Apply closing to smooth boundaries and fully encapsulate holes
        SE_close = strel('disk', 15);
        RNH_hole = imclose(RNH_hole, SE_close);
        
        % Additional dilation to ensure full coverage
        SE_expand = strel('disk', 5);
        RNH_hole = imdilate(RNH_hole, SE_expand);
        
        % Remove very small regions again after morphological operations
        RNH_hole = bwareaopen(RNH_hole, 200);

        % Display all intermediate processing steps for debugging/inspection
        displayProcessingSteps(image, gray_img, filtered_image, entropy_normalized, std_normalized, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, RNH_hole);

        save(fullfile(pwd, 'RNpic.mat'), 'RNH_filledMask',"RNH_DefectMask","RNH_hole");

        % Find the connected components in the stitch mask
        holes_cc = bwconncomp(RNH_hole);

        % Calculate the properties of connected components
        holes_props = regionprops(holes_cc, 'BoundingBox', 'Area');

        % Threshold for minimum area of detected hole (adjust as needed)
        min_hole_area = 150;

        % Filter out small holes based on area threshold
        large_holes = holes_props([holes_props.Area] > min_hole_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'large_holes');

        % Display results
        displayResults(image, large_holes, RNH_hole);

    catch ME
        disp(ME.message);
    end
end

function displayResults(original_img, large_holes, hole_mask)
    % Display the detection results
    figure('Name', 'Rubber Nitrile Hole Detection Results', 'NumberTitle', 'off');
    
    % Show original image with bounding boxes
    subplot(1, 2, 1);
    imshow(original_img);
    title(sprintf('Detected Holes: %d', length(large_holes)));
    hold on;
    
    % Draw bounding boxes around detected holes
    for i = 1:length(large_holes)
        bbox = large_holes(i).BoundingBox;
        rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
        
        % Add label with hole number
        text(bbox(1), bbox(2)-5, sprintf('Hole %d', i), ...
             'Color', 'red', 'FontSize', 10, 'FontWeight', 'bold', ...
             'BackgroundColor', 'white');
    end
    hold off;
    
    % Show mask overlay
    subplot(1, 2, 2);
    imshow(labeloverlay(original_img, hole_mask, 'Transparency', 0.5));
    title('Hole Mask Overlay');
    
    % Print summary
    fprintf('\n=== HOLE DETECTION SUMMARY ===\n');
    fprintf('Total holes detected: %d\n', length(large_holes));
    if ~isempty(large_holes)
        fprintf('\nHole Details:\n');
        for i = 1:length(large_holes)
            fprintf('  Hole %d - Area: %.0f pixels\n', i, large_holes(i).Area);
        end
    end
    fprintf('==============================\n\n');
end

function displayProcessingSteps(original_img, gray_img, filtered_image, entropy_norm, std_norm, texture_score, texture_mask, bwImg, inverted_bwImg, filledImg, RNH_filledMask, RNH_DefectMask, intensity_holes, combined_holes, final_hole_mask)
    % Display step-by-step intermediate outputs in a tiled figure
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
        subplot(4,4,15); imshow(final_hole_mask); title('Final Hole Mask (morph ops)');
        subplot(4,4,16); imshow(labeloverlay(original_img, final_hole_mask, 'Transparency', 0.6)); title('Overlay: Holes on Image');

        drawnow;
    catch
        % If any visualization step fails, close figure and continue
        if ishandle(h), close(h); end
    end
end
