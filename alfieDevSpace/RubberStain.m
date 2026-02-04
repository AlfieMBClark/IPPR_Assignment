function RubberNitrileStainDetector(input_image)
    try
        % Preprocessing using shared utilities
        gray_image = GloveDetectionUtils.convertToGrayscale(input_image);
        filtered_image = GloveDetectionUtils.applyMedianFilter(gray_image, [3, 3]);

        % Thresholding
        threshold_value = 0.4; 
        binary_image = imbinarize(filtered_image, threshold_value);
        inverted_binary_image = ~binary_image;
        SE0 = strel('disk', 3);
        inverted_binary_image = imopen(inverted_binary_image, SE0);

        % Fill any holes in the binary image
        filled_image = imfill(inverted_binary_image, 'holes');

        % Get the largest connected component (Glove) using shared utility
        RNS_glove_mask = GloveDetectionUtils.extractGloveMask(filled_image, 1);

        % Morphological opening to remove noise and small objects
        neighborhood = ones(5); 
        structuring_element = strel(neighborhood);
        RNS_defect_mask = imopen(inverted_binary_image, structuring_element);

        RNS_stain_mask = imsubtract(RNS_glove_mask, RNS_defect_mask);
        RNS_stain_mask = im2bw(RNS_stain_mask);
        SE1 = strel('square', 2);
        RNS_stain_mask = imopen(RNS_stain_mask, SE1);
        
        save(fullfile(pwd, 'RNpic.mat'), 'RNS_glove_mask',"RNS_defect_mask","RNS_stain_mask");

        % Detect and filter defects using shared utility
        min_stain_area = 20;
        [large_stains, RNS_stain_mask_filtered] = GloveDetectionUtils.detectAndFilterDefects(RNS_stain_mask, min_stain_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'large_stains');

        % Display all intermediate processing steps
        displayProcessingSteps(input_image, gray_image, filtered_image, binary_image, inverted_binary_image, filled_image, RNS_glove_mask, RNS_defect_mask, RNS_stain_mask);

        % Display final results using shared utility
        GloveDetectionUtils.displayDefectResults(input_image, large_stains, RNS_stain_mask_filtered, 'Stain');

    catch ME
        disp(ME.message);
    end
end

function displayProcessingSteps(original_img, gray_img, filtered_img, binary_img, inverted_binary, filled_img, glove_mask, defect_mask, stain_mask)
    % Display step-by-step intermediate outputs in a tiled figure
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

        subplot(3,4,9); imshow(stain_mask); title('9. Stain Mask');
        subplot(3,4,10); imshow(labeloverlay(original_img, stain_mask, 'Transparency', 0.6)); title('10. Stain Overlay');
        subplot(3,4,11); imshow(labeloverlay(original_img, glove_mask, 'Colormap', 'spring', 'Transparency', 0.3)); title('11. Glove Mask Overlay');
        subplot(3,4,12); imshow(labeloverlay(original_img, defect_mask, 'Colormap', 'autumn', 'Transparency', 0.4)); title('12. Defect Mask Overlay');

        drawnow;
    catch
        % If any visualization step fails, close figure and continue
        if ishandle(h), close(h); end
    end
end