function finalResults = mainNylon(imgPath, debugMode)

    %Default Args
    if nargin < 2
        debugMode = false;
    end

    if nargin < 1 || isempty(imgPath)
        [file, folder] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp', 'Image Files'}, ...
            'Select a glove image');

        if isequal(file, 0)
            disp('No file selected.');
            finalResults = [];
            return;
        end
        imgPath = fullfile(folder, file);
    end

    %Load and resize image once — passed to all detectors
    fprintf('\n=============================\n');
    fprintf(' Glove Defect Detection\n');
    fprintf('=============================\n');
    fprintf('Image: %s\n\n', imgPath);

    img = imread(imgPath);
    if max(size(img, 1), size(img, 2)) > 800
        scale = 800 / max(size(img, 1), size(img, 2));
        img   = imresize(img, scale);
    end

    %Run all three detectors
    fprintf('Running hole detection...\n');
    holeResults = detectNylonHole(img, debugMode);

    fprintf('Running missing fingertip detection...\n');
    tipResults  = detectNylonMissingFingertip(img, debugMode);

    fprintf('Running loose thread detection...\n');
    threadResults = detectNylonLooseThreads(img, debugMode);

    %Layer all annotations onto one combined image
    combined = img;
    combined = layerAnnotations(combined, img, holeResults.annotated);
    combined = layerAnnotations(combined, img, tipResults.annotated);
    combined = layerAnnotations(combined, img, threadResults.annotated);

    %Build defect summary
    defectSummary = {};
    if holeResults.defectFound
        defectSummary{end+1} = sprintf('Hole — %d region(s)', holeResults.numHoles);
    end
    if tipResults.defectFound
        defectSummary{end+1} = sprintf('Missing Fingertip — %d region(s)', tipResults.numDefects);
    end
    if threadResults.defectFound
        defectSummary{end+1} = sprintf('Loose Thread — %d region(s)', threadResults.numDefects);
    end
    if isempty(defectSummary)
        defectSummary{1} = 'No defects detected';
    end

    %Print summary
    fprintf('\n--- RESULTS ---\n');
    for k = 1 : numel(defectSummary)
        fprintf('  %s\n', defectSummary{k});
    end
    fprintf('---------------\n\n');

    %Display combined result
    figure('Name', 'GDD — Final Result', 'NumberTitle', 'off');
    tiledlayout(1, 2, 'TileSpacing', 'compact');

    nexttile; imshow(img);
    title('Original Image', 'FontSize', 13);

    nexttile; imshow(combined);
    title(strjoin(defectSummary, '  |  '), 'FontSize', 11);

    %Package results
    finalResults.imagePath         = imgPath;
    finalResults.holes             = holeResults;
    finalResults.missingTip        = tipResults;
    finalResults.threads           = threadResults;
    finalResults.anyDefectFound    = holeResults.defectFound || ...
                                     tipResults.defectFound  || ...
                                     threadResults.defectFound;
    finalResults.defectSummary     = defectSummary;
    finalResults.combinedAnnotated = combined;

end