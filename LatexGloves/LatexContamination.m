function RubberContamination(input_img, showFigures)
% RUBBERCONTAMINATION - Detect dirt/contamination on a red latex glove
%
% Workflow:
%   1. Build glove mask + safe search zone (same shadow exclusion as foreign object)
%   2. HSV color shift: dirty pixels shift hue toward brown, saturation drops
%   3. Texture anomaly: dirt creates rough/uneven patches (local std dev)
%   4. AND both detections: must be BOTH color-shifted AND texture-anomalous
%   5. Size filtering: catches both large patches and small spots
input_img = imread("./Latex Glove/ContamwHole.jpeg");
    if nargin < 2, showFigures = true; end

    try
        %% ── STEP 1: PREPROCESS ───────────────────────────────────────────
        gray_img     = GloveDetectionUtils.convertToGrayscale(input_img);
        filtered_img = GloveDetectionUtils.applyMedianFilter(gray_img, [5 5]);

        hsv_img = rgb2hsv(input_img);
        H = hsv_img(:,:,1);
        S = hsv_img(:,:,2);
        V = hsv_img(:,:,3);

        %% ── STEP 2: BACKGROUND MASK ──────────────────────────────────────
        background_mask = (S < 0.15) & (V > 0.55);           % ← TUNE
        background_mask = bwareaopen(background_mask, 3000);
        background_mask = bwareafilt(background_mask, 1);

        %% ── STEP 3: GLOVE MASK ───────────────────────────────────────────
        glove_red = ((H < 0.05) | (H > 0.92)) & ...          % ← TUNE hue
                    (S > 0.50) & (V > 0.10) & (V < 0.95) & ...
                    ~background_mask;
        glove_red = medfilt2(glove_red, [5 5]);
        glove_red = bwareaopen(glove_red, 1000);
        glove_red = bwareafilt(glove_red, 1);

        glove_filled = imfill(glove_red, 'holes');
        glove_filled = GloveDetectionUtils.extractGloveMask(glove_filled, 5);
        glove_filled = glove_filled & ~background_mask;

        % Shadow exclusion — same logic as foreign object detector
        shadow_zone   = glove_filled & ~imerode(glove_filled, strel('disk', 14)); % ← TUNE
        safe_interior = glove_filled & ~shadow_zone;

        %% ── STEP 4: MEASURE CLEAN GLOVE BASELINE ────────────────────────
        % Sample the clean red glove's average HSV values from glove_red pixels.
        % Contamination deviates from this baseline.
        H_glove = H(glove_red);
        S_glove = S(glove_red);
        V_glove = V(glove_red);

        S_mean = mean(S_glove(:));   S_std = std(S_glove(:));
        V_mean = mean(V_glove(:));   V_std = std(V_glove(:));

        %% ── STEP 5A: HSV COLOR SHIFT DETECTION ──────────────────────────
        % Dark brown/mud contamination causes:
        %   Hue   → shifts away from pure red toward orange-brown (H 0.03–0.15)
        %   Sat   → drops noticeably (dirt desaturates the vivid red)
        %   Value → gets darker (mud is darker than glove)

        % Hue shifted toward brown (no longer pure red)
        hue_shifted = (H > 0.04) & (H < 0.20);               % ← TUNE: brown/mud hue range

        % Saturation significantly lower than clean glove average
        sat_dropped = S < (S_mean - 1.2 * S_std);            % ← TUNE: sensitivity multiplier

        % Value darker than clean glove average
        val_dark    = V < (V_mean - 1.0 * V_std);            % ← TUNE: darkness sensitivity

        % Color anomaly = hue shifted OR (saturation dropped AND darker)
        color_anomaly = hue_shifted | (sat_dropped & val_dark);
        color_anomaly = color_anomaly & safe_interior & ~background_mask;
        color_anomaly = medfilt2(color_anomaly, [5 5]);       % smooth noise

        %% ── STEP 5B: TEXTURE ANOMALY DETECTION ──────────────────────────
        % Dirt creates rough, uneven surface texture.
        % Local standard deviation measures how much pixel values vary nearby.
        % Clean glove = low local std (smooth, uniform)
        % Dirty patch = high local std (rough, irregular)

        std_img  = stdfilt(filtered_img, ones(9));            % ← TUNE: window size
        std_norm = mat2gray(std_img);

        % Measure clean glove's typical texture level
        std_glove_vals = std_norm(glove_red);
        std_mean = mean(std_glove_vals(:));
        std_std  = std(std_glove_vals(:));

        % Flag pixels with unusually high texture variation
        texture_anomaly = std_norm > (std_mean + 1.5 * std_std); % ← TUNE multiplier
        texture_anomaly = texture_anomaly & safe_interior & ~background_mask;
        texture_anomaly = medfilt2(texture_anomaly, [5 5]);

        %% ── STEP 5C: LOCAL BRIGHTNESS ANOMALY ───────────────────────────
        % Mud patches are locally darker than the surrounding glove area.
        % Compare each pixel to its local neighbourhood average.
        V_double    = double(V);
        V_local_avg = imgaussfilt(V_double, 12);              % ← TUNE: neighbourhood size
        V_diff      = V_local_avg - V_double;                 % positive = darker than surroundings
        bright_anomaly = V_diff > 0.08;                       % ← TUNE: darkness threshold
        bright_anomaly = bright_anomaly & safe_interior & ~background_mask;
        bright_anomaly = medfilt2(bright_anomaly, [5 5]);

        %% ── STEP 6: COMBINE DETECTIONS ──────────────────────────────────
        % Strategy: color shift + at least one of (texture OR brightness)
        % This avoids wrinkles (texture only) and lighting variation (brightness only)
        % being falsely flagged as contamination.
        contamination_mask = color_anomaly & (texture_anomaly | bright_anomaly);

        %% ── STEP 7: MORPHOLOGICAL CLEANUP ───────────────────────────────
        % Clean up noise and merge nearby patches
        contamination_mask = imopen(contamination_mask, strel('disk', 2));  % ← TUNE
        contamination_mask = bwareaopen(contamination_mask, 60);            % ← TUNE small spot min size
        contamination_mask = imclose(contamination_mask, strel('disk', 8)); % ← TUNE merge gap
        contamination_mask = imfill(contamination_mask, 'holes');
        contamination_mask = bwareaopen(contamination_mask, 100);           % ← TUNE final min size

        %% ── STEP 8: SAVE + DETECT ────────────────────────────────────────
        RNC_contamination_mask = contamination_mask;
        save(fullfile(pwd, 'RNpic.mat'), ...
            'glove_red', 'glove_filled', 'shadow_zone', 'safe_interior', ...
            'color_anomaly', 'texture_anomaly', 'bright_anomaly', ...
            'RNC_contamination_mask');

        min_contam_area = 100;                                % ← TUNE
        [large_contamination, contam_mask_filtered] = ...
            GloveDetectionUtils.detectAndFilterDefects(contamination_mask, min_contam_area);

        save(fullfile(pwd, 'RNvariables.mat'), 'large_contamination');

        %% ── STEP 9: DISPLAY ─────────────────────────────────────────────
        if showFigures
            figure('Name', 'Processing Steps - Contamination Detection', ...
                   'NumberTitle', 'off', 'Position', [50 50 1500 900]);

            subplot(3,4,1);  imshow(input_img);                                 title('1. Original RGB');
            subplot(3,4,2);  imshow(glove_filled);                              title('2. Glove Mask (filled)');
            subplot(3,4,3);  imshow(shadow_zone);                               title('3. Shadow Zone (excluded)');
            subplot(3,4,4);  imshow(safe_interior);                             title('4. Safe Search Zone');

            subplot(3,4,5);  imshow(color_anomaly);                             title('5. Color Anomaly (HSV shift)');
            subplot(3,4,6);  imagesc(std_norm); axis image off; colormap(gca, hot);
                                                                                title('6. Local Texture (std dev)');
            subplot(3,4,7);  imshow(texture_anomaly);                           title('7. Texture Anomaly');
            subplot(3,4,8);  imshow(bright_anomaly);                            title('8. Brightness Anomaly');

            subplot(3,4,9);  imshow(contamination_mask);                        title('9. Combined (color AND texture/bright)');
            subplot(3,4,10); imshow(contam_mask_filtered);                      title('10. Final Contamination Mask');
            subplot(3,4,11); imshow(labeloverlay(input_img, contam_mask_filtered, ...
                              'Colormap', [0.6 0.3 0], 'Transparency', 0.40)); title('11. Final Overlay (brown)');

            subplot(3,4,12); imshow(input_img); hold on;
            title(sprintf('12. Detected: %d Contamination(s)', numel(large_contamination)));
            for i = 1:numel(large_contamination)
                bb = large_contamination(i).BoundingBox;
                rectangle('Position', bb, 'EdgeColor', [0.6 0.3 0], 'LineWidth', 2);
                text(bb(1), bb(2)-6, sprintf('Contamination %d', i), ...
                     'Color', [0.6 0.3 0], 'FontSize', 9, 'FontWeight', 'bold', ...
                     'BackgroundColor', 'white', 'Margin', 1);
            end
            hold off;
        end

    catch ME
        disp(ME.message);
    end
end