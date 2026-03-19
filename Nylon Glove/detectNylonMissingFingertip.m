function results = detectNylonMissingFingertip(imgInput, debugMode)

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

    %Gaussian Blur
    imgSmooth = imgaussfilt(img, 1.5);

    %Convert image to HSV
    imgHSV = rgb2hsv(imgSmooth);
    H = imgHSV(:,:,1);
    S = imgHSV(:,:,2);
    V = imgHSV(:,:,3);

    %Step 1 — Segment the glove (blue pixels only)
    gloveMask = (H >= 0.55) & (H <= 0.72) & ...
                (S >= 0.30) & (S <= 1.00) & ...
                (V >= 0.15) & (V <= 1.00);

    gloveMask = imclose(gloveMask, strel('disk', 15));
    gloveMask = bwareaopen(gloveMask, 500);

    %Keep largest connected component
    cc       = bwconncomp(gloveMask);
    numPx    = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPx);
    gloveMask = false(h, w);
    gloveMask(cc.PixelIdxList{idx}) = true;

    %Step 2 — Segment the full hand shape (everything that is not background)
    %The marble background is light, low saturation and high value
    %So background = low saturation OR very high value with no colour
    %Hand/glove = anything that is NOT background
    bgMask = (S <= 0.12) & (V >= 0.55);   % background: grey/white marble
    handMask = ~bgMask;

    %Clean up hand mask
    handMask = imclose(handMask, strel('disk', 10));
    handMask = bwareaopen(handMask, 500);

    %Keep largest connected component of hand mask
    cc_hand       = bwconncomp(handMask);
    numPx_hand    = cellfun(@numel, cc_hand.PixelIdxList);
    [~, idx_hand] = max(numPx_hand);
    handMask = false(h, w);
    handMask(cc_hand.PixelIdxList{idx_hand}) = true;

    %Step 3 — Subtract glove from hand
    %Dilate glove mask slightly to eliminate thin boundary slivers
    gloveMask_dilated = imdilate(gloveMask, strel('disk', 5));
    exposedMask = handMask & ~gloveMask_dilated;
    exposedMask = bwareaopen(exposedMask, 40);

    %Remove inter-finger gaps
    glove_hull       = bwconvhull(gloveMask);
    inter_finger_gap = glove_hull & ~gloveMask;
    exposedMask      = exposedMask & ~inter_finger_gap;

    %Remove small noise
    exposedMask = bwareaopen(exposedMask, 40);

    %Only top 50% of image
    exposedMask(round(h * 0.50):end, :) = false;

    %Only top 50% of image
    exposedMask(round(h * 0.50):end, :) = false;

    %Remove small noise blobs
    exposedMask = bwareaopen(exposedMask, 40);

    %Step 4 — Filter exposed regions to fingertip area only
    %Only consider regions in the top 50% of the image
    %This avoids picking up the palm or wrist area
    exposedMask(round(h * 0.50):end, :) = false;

    %Step 5 — Each remaining region is a missing fingertip candidate
    props   = regionprops(exposedMask, 'Area', 'BoundingBox', 'Centroid');
    keepIdx = false(numel(props), 1);

    for k = 1 : numel(props)
        %Must be a reasonable size — not too tiny (noise) or too large (hole)
        if props(k).Area >= 40 && props(k).Area <= 5000
            keepIdx(k) = true;
        end
    end

    defect_list = props(keepIdx);

    %Output
    annotated = img;
    thickness = 3;

    for k = 1 : numel(defect_list)
        bb = defect_list(k).BoundingBox;

        pad = 10;
        x1  = max(1, round(bb(1) - pad));
        y1  = max(1, round(bb(2) - pad));
        x2  = min(w, round(bb(1) + bb(3) + pad));
        y2  = min(h, round(bb(2) + bb(4) + pad));

        %Draw yellow rectangle border
        annotated(y1:y2, x1:x2, 1) = 255;
        annotated(y1:y2, x1:x2, 2) = 255;
        annotated(y1:y2, x1:x2, 3) = 0;

        %Hollow out the inside
        annotated(y1+thickness:y2-thickness, x1+thickness:x2-thickness, :) = ...
            img(y1+thickness:y2-thickness, x1+thickness:x2-thickness, :);
    end

    %Results
    results.defectFound = numel(defect_list) > 0;
    results.numDefects  = numel(defect_list);
    results.defectStats = defect_list;
    results.annotated   = annotated;
    results.gloveMask   = gloveMask;
    results.handMask    = handMask;
    results.exposedMask = exposedMask;

    %Debug View
    if debugMode
        figure('Name', 'detectMissingFingertip — Debug', 'NumberTitle', 'off');
        tiledlayout(2, 3, 'TileSpacing', 'compact');

        nexttile; imshow(img);
        title('1. Original');

        nexttile; imshow(gloveMask);
        title('2. Glove Mask (blue only)');

        nexttile; imshow(handMask);
        title('3. Hand Mask (non-background)');

        nexttile; imshow(handMask & ~gloveMask);
        title('4. Hand minus Glove (raw)');

        nexttile; imshow(exposedMask);
        title('5. Exposed Skin (filtered)');

        nexttile; imshow(annotated);
        title(sprintf('6. Result — %d missing tip(s)', numel(defect_list)));
    end

end