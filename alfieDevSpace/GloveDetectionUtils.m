classdef GloveDetectionUtils
    %Shared utility functions for glove defect detection - Alfie
    %preprocessing, morphological, and visualization
    methods(Static)
        
        %graysca;e
        function gray_img = convertToGrayscale(input_img)
            if size(input_img, 3) == 3
                gray_img = rgb2gray(input_img);
            else
                gray_img = input_img;
            end
        end
        
        %median filtering
        function filtered_img = applyMedianFilter(gray_img, kernelSize)
            if nargin < 2
                kernelSize = [3, 3];
            end
            filtered_img = medfilt2(gray_img, kernelSize);
        end
        
        %gaussian
        function filtered_img = applyGaussianFilter(gray_img, sigma)
            if nargin < 2
                sigma = 4;
            end
            filtered_img = imgaussfilt(gray_img, sigma);
        end
        
        %get glove frm binary image
        function glove_mask = extractGloveMask(binary_img, dilateRadius)
            if nargin < 2
                dilateRadius = 1;
            end
            
            % Fill holes
            filled_img = imfill(binary_img, 'holes');
            % Get glove
            glove_mask = bwareafilt(filled_img, 1);
            %expand mask
            if dilateRadius > 0
                SE = strel('disk', dilateRadius);
                glove_mask = imdilate(glove_mask, SE);
            end
        end
        
        %Filter min area
        function filtered_props = filterByArea(region_props, min_area)
            filtered_props = region_props([region_props.Area] > min_area);
        end
        
        %morphological remove small objects
        function opened_img = applyMorphologicalOpening(binary_img, structuringElement)
            if isnumeric(structuringElement)
                structuringElement = strel(structuringElement);
            end
            opened_img = imopen(binary_img, structuringElement);
        end
        
        function displayDefectResults(original_img, defects, defect_mask, defect_type)     
            figure('Name', sprintf('Rubber Nitrile %s Detection Results', defect_type), ...
                   'NumberTitle', 'off');
            
            subplot(1, 2, 1);
            imshow(original_img);
            title(sprintf('Detected %ss: %d', defect_type, length(defects)));
            hold on;
            %bbox
            for i = 1:length(defects)
                bbox = defects(i).BoundingBox;
                rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
                %label+num
                 text(bbox(1), bbox(2)-5, sprintf('%s %d', defect_type, i), 'Color', 'red', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', 'white');
            end
            hold off;
        
            %mask overlay
            subplot(1, 2, 2);
            imshow(labeloverlay(original_img, defect_mask, 'Transparency', 0.5));
            title(sprintf('%s Mask Overlay', defect_type));
            
            %summary
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
        
        % Detect connected components and filter by area
        function [defect_props, defect_mask_filtered] = detectAndFilterDefects(defect_mask, min_area)
            %get connected components
            cc = bwconncomp(defect_mask);

            component_areas = cellfun(@numel, cc.PixelIdxList);
            keep_idx = find(component_areas > min_area);

            % Create filtered mask
            defect_mask_filtered = false(size(defect_mask));
            for i = 1:numel(keep_idx)
                defect_mask_filtered(cc.PixelIdxList{keep_idx(i)}) = true;
            end

            % Measure properties from the same filtered mask used for overlay.
            cc_filtered = bwconncomp(defect_mask_filtered);
            defect_props = regionprops(cc_filtered, 'BoundingBox', 'Area');
        end
        
        function saveDetectionResults(save_path, masks_struct, results_struct)
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
        
        % Create figure for processing steps
        function fig_handle = createProcessingFigure(title_text, num_rows, num_cols)
            width = 300 * num_cols;
            height = 250 * num_rows;
            
            fig_handle = figure('Name', title_text,'NumberTitle','off','Position', [50 50 width height]);
        end
        
        % Merge nearby detections dilation + erosion
        function mergeCloseRegions(binary_mask, dilate_radius, erode_radius)
            if nargin < 2, dilate_radius = 8; end
            if nargin < 3, erode_radius = 2; end
            
            % Dilate to merge
            SE_merge = strel('disk', dilate_radius);
            merged = imdilate(binary_mask, SE_merge);
            % Fill holes
            merged = imfill(merged, 'holes');
            % Closing to smooth
            SE_close = strel('disk', floor(dilate_radius/2));
            merged = imclose(merged, SE_close);
            %erosion to refine edges
            if erode_radius > 0
                SE_erode = strel('disk', erode_radius);
                merged = imerode(merged, SE_erode);
            end
            % Final fill
            merged = imfill(merged, 'holes');
        end
        
    end
end
