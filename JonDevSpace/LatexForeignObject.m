function LatexForeignObject(input_img, showFigures)
% LATEXFOREIGNOBJECT - Detect foreign objects on a red latex glove
%
% Step by step:
%   1. Grayscale + median filter (preprocessing)
%   2. HSV conversion
%   3. Separate background from hand+glove
%   4. Extract red glove from the hand+glove region
%   5. Anything not red glove within the hand+glove = foreign object
input_img = imread("./Latex Glove/ForeignObject.jpeg");

    if nargin < 2, showFigures = true; end

    try
        %% ── STEP 1: GRAYSCALE + MEDIAN FILTER ───────────────────────────
        gray_img     = GloveDetectionUtils.convertToGrayscale(input_img);
        filtered_img = GloveDetectionUtils.applyMedianFilter(gray_img, [5 5]);

        %% ── STEP 2: HSV ──────────────────────────────────────────────────
        hsv_img = rgb2hsv(input_img);
        H = hsv_img(:,:,1);
        S = hsv_img(:,:,2);
        V = hsv_img(:,:,3);

        %% ── STEP 3: SEPARATE BACKGROUND FROM HAND+GLOVE ─────────────────
        % Background = plain white/grey = low saturation + high brightness
        % Everything that is NOT background = hand + glove region
        background_mask = (S < 0.15) & (V > 0.55);           % ← TUNE
        background_mask = bwareaopen(background_mask, 3000);  % remove small bg blobs
        background_mask = bwareafilt(background_mask, 1);     % keep largest bg region only

        % Hand+glove region = everything that is not background
        hand_glove_region = ~background_mask;
        hand_glove_region = bwareaopen(hand_glove_region, 1000);
        hand_glove_region = bwareafilt(hand_glove_region, 1); % keep largest = the hand+glove
        hand_glove_region = imfill(hand_glove_region, 'holes');

        %% ── STEP 4: EXTRACT RED GLOVE FROM HAND+GLOVE REGION ────────────
        % Within the hand+glove region, find what is red latex
        % Red in HSV wraps around H=0: check both H<threshold and H>threshold
        is_red_glove = ((H < 0.05) | (H > 0.92)) & ...       % ← TUNE hue range
                       (S > 0.50)  & ...                      % ← TUNE saturation: vivid red
                       (V > 0.10)  & (V < 0.95) & ...        % ← TUNE brightness range
                       hand_glove_region;                     % must be inside hand+glove

        is_red_glove = medfilt2(is_red_glove, [5 5]);         % smooth edges
        is_red_glove = bwareaopen(is_red_glove, 500);         % remove small red blobs
        is_red_glove = bwareafilt(is_red_glove, 1);           % keep largest red = the glove

        % Fill the glove to a solid shape
        glove_filled = imfill(is_red_glove, 'holes');
        glove_filled = GloveDetectionUtils.extractGloveMask(glove_filled, 3);

        % Shadow zone: thin ring at glove boundary, never search here
        shadow_zone   = glove_filled & ~imerode(glove_filled, strel('disk', 14)); % ← TUNE
        safe_interior = glove_filled & ~shadow_zone;

        %% ── STEP 5: NOT RED GLOVE = FOREIGN OBJECT ──────────────────────
        % Inside the safe glove interior, anything that is not red = foreign object
        % This catches: plastic, rubber band, clip, any other object
        foreign_mask = ~is_red_glove & safe_interior;

        %% ── STEP 6: CLEANUP ──────────────────────────────────────────────
        foreign_mask = medfilt2(foreign_mask, [3 3]);
        foreign_mask = bwareaopen(foreign_mask, 50);            % ← TUNE remove tiny specks
        foreign_mask = imclose(foreign_mask, strel('disk', 8)); % ← TUNE merge nearby fragments
        foreign_mask = imfill(foreign_mask, 'holes');
        foreign_mask = bwareaopen(foreign_mask, 150);           % ← TUNE final min object size

        %% ── STEP 7: SAVE + DETECT ────────────────────────────────────────
        RL_foreign_mask = foreign_mask;
        save(fullfile(pwd, 'RNpic.mat'), ...
            'is_red_glove', 'glove_filled', 'shadow_zone', ...
            'safe_interior', 'RL_foreign_mask');

        min_foreign_area = 150;                                 % ← TUNE
        [foreign_objects, foreign_mask_filtered] = ...
            GloveDetectionUtils.detectAndFilterDefects(RL_foreign_mask, min_foreign_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'foreign_objects');

        %% ── STEP 8: DISPLAY ─────────────────────────────────────────────
        if showFigures
            figure('Name', 'Foreign Object Detection', ...
                   'NumberTitle', 'off', 'Position', [50 50 1400 700]);

            subplot(2,4,1); imshow(input_img);                   title('1. Original RGB');
            subplot(2,4,2); imshow(filtered_img);                title('2. Grayscale + Median');
            subplot(2,4,3); imshow(background_mask);             title('3. Background');
            subplot(2,4,4); imshow(hand_glove_region);           title('4. Hand + Glove Region');

            subplot(2,4,5); imshow(is_red_glove);                title('5. Red Glove Only');
            subplot(2,4,6); imshow(safe_interior);               title('6. Safe Search Zone');
            subplot(2,4,7); imshow(foreign_mask_filtered);       title('7. Foreign Object Mask');
            subplot(2,4,8); imshow(labeloverlay(input_img, foreign_mask_filtered, ...
                            'Colormap', [1 1 0], 'Transparency', 0.45));
                            title('8. Final Overlay');

            GloveDetectionUtils.displayDefectResults(input_img, ...
                foreign_objects, foreign_mask_filtered, 'Foreign Object');
        end

    catch ME
        disp(ME.message);
    end
end