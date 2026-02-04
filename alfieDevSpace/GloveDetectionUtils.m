classdef GloveDetectionUtils
    % GLOVEDETECTIONUTILS - Shared utility functions for glove defect detection
    % Collection of common preprocessing, morphological, and visualization
    % functions used across hole, stain, and missing finger detectors.
    
    methods(Static)
        
        function gray_img = convertToGrayscale(input_img)
            % Convert RGB image to grayscale
            % Returns already-gray images unchanged
            if size(input_img, 3) == 3
                gray_img = rgb2gray(input_img);
            else
                gray_img = input_img;
            end
        end
        
        function filtered_img = applyMedianFilter(gray_img, kernelSize)
            % Apply median filtering for noise reduction
            % kernelSize: [rows, cols] default [3, 3]
            if nargin < 2
                kernelSize = [3, 3];
            end
            filtered_img = medfilt2(gray_img, kernelSize);
        end
        
        function filtered_img = applyGaussianFilter(gray_img, sigma)
            % Apply Gaussian filtering for smoothing
            % sigma: standard deviation, default 4
            if nargin < 2
                sigma = 4;
            end
            filtered_img = imgaussfilt(gray_img, sigma);
        end
        
        function glove_mask = extractGloveMask(binary_img, dilateRadius)
            % Extract the largest connected component (glove) from binary image
            % binary_img: binary image with glove as largest object
            % dilateRadius: disk radius for dilation, default 1
            if nargin < 2
                dilateRadius = 1;
            end
            
            % Fill holes in binary image
            filled_img = imfill(binary_img, 'holes');
            
            % Get largest connected component (the glove)
            glove_mask = bwareafilt(filled_img, 1);
            
            % Dilate to expand mask slightly
            if dilateRadius > 0
                SE = strel('disk', dilateRadius);
                glove_mask = imdilate(glove_mask, SE);
            end
        end
        
        function filtered_props = filterByArea(region_props, min_area)
            % Filter region properties by minimum area threshold
            % region_props: output from regionprops
            % min_area: minimum area in pixels
            filtered_props = region_props([region_props.Area] > min_area);
        end
        
        function opened_img = applyMorphologicalOpening(binary_img, structuringElement)
            % Apply morphological opening to remove small objects
            % structuringElement: strel object or neighborhood matrix
            if isnumeric(structuringElement)
                structuringElement = strel(structuringElement);
            end
            opened_img = imopen(binary_img, structuringElement);
        end
        
        function displayDefectResults(original_img, defects, defect_mask, defect_type)
            % Unified display function for detection results
            % original_img: original RGB image
            % defects: array of region props with BoundingBox and Area
            % defect_mask: binary mask of detected defects
            % defect_type: string ('Hole', 'Stain', 'Missing Finger')
            
            figure('Name', sprintf('Rubber Nitrile %s Detection Results', defect_type), ...
                   'NumberTitle', 'off');
            
            % Show original image with bounding boxes
            subplot(1, 2, 1);
            imshow(original_img);
            title(sprintf('Detected %ss: %d', defect_type, length(defects)));
            hold on;
            
            % Draw bounding boxes around detected defects
            for i = 1:length(defects)
                bbox = defects(i).BoundingBox;
                rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
                
                % Add label with defect number
                text(bbox(1), bbox(2)-5, sprintf('%s %d', defect_type, i), ...
                     'Color', 'red', 'FontSize', 10, 'FontWeight', 'bold', ...
                     'BackgroundColor', 'white');
            end
            hold off;
            
            % Show mask overlay
            subplot(1, 2, 2);
            imshow(labeloverlay(original_img, defect_mask, 'Transparency', 0.5));
            title(sprintf('%s Mask Overlay', defect_type));
            
            % Print summary to console
            fprintf('\n=== %s DETECTION SUMMARY ===\n', upper(defect_type));
            fprintf('Total %ss detected: %d\n', lower(defect_type), length(defects));
            if ~isempty(defects)
                fprintf('\n%s Details:\n', defect_type);
                for i = 1:length(defects)
                    fprintf('  %s %d - Area: %.0f pixels\n', defect_type, i, defects(i).Area);
                end
            else
                fprintf('No %ss detected - glove appears clean.\n', lower(defect_type));
            end
            fprintf('%s\n\n', repmat('=', 1, length(defect_type) + 26));
        end
        
        function [defect_props, defect_mask_filtered] = detectAndFilterDefects(defect_mask, min_area)
            % Detect connected components and filter by area
            % defect_mask: binary mask of potential defects
            % min_area: minimum area threshold in pixels
            % Returns: filtered region props and cleaned mask
            
            % Find connected components
            cc = bwconncomp(defect_mask);
            
            % Calculate properties
            defect_props = regionprops(cc, 'BoundingBox', 'Area');
            
            % Filter by area
            defect_props = GloveDetectionUtils.filterByArea(defect_props, min_area);
            
            % Create filtered mask
            defect_mask_filtered = false(size(defect_mask));
            if ~isempty(defect_props)
                for i = 1:length(defect_props)
                    defect_mask_filtered = defect_mask_filtered | (labelmatrix(cc) == i);
                end
            end
        end
        
        function saveDetectionResults(save_path, masks_struct, results_struct)
            % Save detection results to .mat files
            % save_path: directory path for saving
            % masks_struct: struct with mask variables
            % results_struct: struct with result variables
            
            % Save masks
            if ~isempty(masks_struct)
                mask_fields = fieldnames(masks_struct);
                for i = 1:length(mask_fields)
                    eval(sprintf('%s = masks_struct.%s;', mask_fields{i}, mask_fields{i}));
                end
                save(fullfile(save_path, 'RNpic.mat'), mask_fields{:});
            end
            
            % Save results
            if ~isempty(results_struct)
                result_fields = fieldnames(results_struct);
                for i = 1:length(result_fields)
                    eval(sprintf('%s = results_struct.%s;', result_fields{i}, result_fields{i}));
                end
                save(fullfile(save_path, 'RNvariables.mat'), result_fields{:});
            end
        end
        
        function fig_handle = createProcessingFigure(title_text, num_rows, num_cols)
            % Create a standardized figure for displaying processing steps
            % title_text: window title
            % num_rows, num_cols: subplot grid dimensions
            % Returns: figure handle
            
            % Calculate appropriate figure size based on grid
            width = 300 * num_cols;
            height = 250 * num_rows;
            
            fig_handle = figure('Name', title_text, ...
                               'NumberTitle', 'off', ...
                               'Position', [50 50 width height]);
        end
        
        function mergeCloseRegions(binary_mask, dilate_radius, erode_radius)
            % Merge nearby detections using dilation-erosion
            % binary_mask: input binary mask
            % dilate_radius: radius for dilation to merge
            % erode_radius: radius for erosion to refine
            % Returns: merged binary mask
            
            if nargin < 2, dilate_radius = 8; end
            if nargin < 3, erode_radius = 2; end
            
            % Dilate to merge nearby regions
            SE_merge = strel('disk', dilate_radius);
            merged = imdilate(binary_mask, SE_merge);
            
            % Fill holes
            merged = imfill(merged, 'holes');
            
            % Closing to smooth
            SE_close = strel('disk', floor(dilate_radius/2));
            merged = imclose(merged, SE_close);
            
            % Light erosion to refine edges
            if erode_radius > 0
                SE_erode = strel('disk', erode_radius);
                merged = imerode(merged, SE_erode);
            end
            
            % Final fill
            merged = imfill(merged, 'holes');
        end
        
    end
end
