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

    catch ME
        disp(ME.message);
    end
end
