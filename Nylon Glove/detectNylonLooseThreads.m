function results = detectNylonLooseThreads(imgInput, debugMode)

    %Default Arg.
    if nargin < 2
        debugMode = false;
    end

    %Loading Image
    if ischar(imgInput) || isstring(imgInput)
        img = imread(imgInput);
    else
        img = imgInput;
    end

    if ~isa(img, 'uint8')
        img = im2uint8(img);
    end

    %Image Preprocessing

    %Resizing Image if too Large
    [h, w, ~] = size(img);
    if max(h, w) > 800
        scale = 800 / max(h, w);
        img   = imresize(img, scale);
        [h, w, ~] = size(img);
    end

    %Lighter blur than other detectors — preserve thin thread structures
    imgSmooth = imgaussfilt(img, 1.0);

    %Convert image to HSV
    imgHSV = rgb2hsv(imgSmooth);
    H = imgHSV(:,:,1);
    S = imgHSV(:,:,2);
    V = imgHSV(:,:,3);

    %Segment the glove to extract blue values
    gloveMask = (H >= 0.55) & (H <= 0.72) & ...
                (S >= 0.30) & (S <= 1.00) & ...
                (V >= 0.15) & (V <= 1.00);

    %Morphology & Clean up
    %Use smaller disk than other detectors to avoid closing over threads
    gloveMask = imclose(gloveMask, strel('disk', 8));
    gloveMask = bwareaopen(gloveMask, 500);

    %Keep largest connected component
    cc       = bwconncomp(gloveMask);
    numPx    = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPx);
    gloveMask = false(h, w);
    gloveMask(cc.PixelIdxList{idx}) = true;

    %Isolate thin protrusions using erosion subtraction method
    %Eroding with a large radius destroys thin structures (threads)
    %but the main glove body survives (just shrinks slightly)
    erode_radius = 6;
    eroded = imerode(gloveMask, strel('disk', erode_radius));

    %Difference between original and eroded = boundary fringe + threads
    diff_mask = gloveMask & ~eroded;

    %Reconstruct expected smooth boundary by dilating eroded mask back
    %Subtracting this from diff_mask leaves only genuine protrusions
    reconstructed    = imdilate(eroded, strel('disk', erode_radius));
    expected_boundary = reconstructed & ~eroded;
    thread_candidates = diff_mask & ~expected_boundary;

    %Remove very small specks
    thread_candidates = bwareaopen(thread_candidates, 15);

    %Filter by shape — threads are elongated and thin
    min_eccentricity = 0.50;   % close to 1 = elongated, close to 0 = circular
    max_solidity     = 0.90;   % low solidity = thin/irregular shape
    min_area         = 5;
    max_area         = 3000;

    props   = regionprops(thread_candidates, 'Area', 'Eccentricity', ...
                          'Solidity', 'BoundingBox', 'Centroid');
    keepIdx = false(numel(props), 1);

    for k = 1 : numel(props)
        A  = props(k).Area;
        E  = props(k).Eccentricity;
        So = props(k).Solidity;

        if A  >= min_area         && ...
           A  <= max_area         && ...
           E  >= min_eccentricity && ...
           So <= max_solidity
            keepIdx(k) = true;
        end
    end

    valid_threads = props(keepIdx);

    %Output
    annotated = img;
    thickness = 3;

    for k = 1 : numel(valid_threads)
        bb = valid_threads(k).BoundingBox;

        pad = 10;
        x1  = max(1, round(bb(1) - pad));
        y1  = max(1, round(bb(2) - pad));
        x2  = min(w, round(bb(1) + bb(3) + pad));
        y2  = min(h, round(bb(2) + bb(4) + pad));

        %Draw cyan rectangle border
        annotated(y1:y2, x1:x2, 1) = 0;
        annotated(y1:y2, x1:x2, 2) = 255;
        annotated(y1:y2, x1:x2, 3) = 255;

        %Hollow out the inside
        annotated(y1+thickness:y2-thickness, x1+thickness:x2-thickness, :) = ...
            img(y1+thickness:y2-thickness, x1+thickness:x2-thickness, :);
    end

    %Results
    results.defectFound      = numel(valid_threads) > 0;
    results.numDefects       = numel(valid_threads);
    results.defectStats      = valid_threads;
    results.annotated        = annotated;
    results.gloveMask        = gloveMask;
    results.threadCandidates = thread_candidates;

    %Debug View
    if debugMode
        figure('Name', 'detectLooseThreads — Debug', 'NumberTitle', 'off');
        tiledlayout(2, 3, 'TileSpacing', 'compact');

        nexttile; imshow(img);
        title('1. Original');

        nexttile; imshow(gloveMask);
        title('2. Glove Mask');

        nexttile; imshow(eroded);
        title(sprintf('3. Eroded Mask (radius = %d)', erode_radius));

        nexttile; imshow(diff_mask);
        title('4. Difference (boundary + threads)');

        nexttile; imshow(thread_candidates);
        title('5. Thread Candidates');

        nexttile; imshow(annotated);
        title(sprintf('6. Result — %d thread(s)', numel(valid_threads)));
    end

end