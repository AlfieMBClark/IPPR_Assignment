function results = detectNylonHole(imgInput, debugMode)

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

    %Gaussian Blur to ensire mesh isnt mistaken as holes.
    imgSmooth = imgaussfilt(img, 1.5);
    
    %Convert image to HSV 
    imgHSV = rgb2hsv(imgSmooth);
    H = imgHSV(:,:,1);
    S = imgHSV(:,:,2);
    V = imgHSV(:,:,3);

    %Segment the glove to extract blue values as glove is blue
    gloveMask = (H >= 0.55) & (H <= 0.72) & ...
                (S >= 0.30) & (S <= 1.00) & ...
                (V >= 0.15) & (V <= 1.00);

    %Morphology & Clean up: closing the image first to seal gaps caused by
    %mesh texture of fabric followed by opening to remove stray blobs.
    gloveMask = imclose(gloveMask, strel('disk', 10));
    gloveMask = bwareaopen(gloveMask, 500);
 
    % Keep largest connected component
    cc        = bwconncomp(gloveMask);
    numPx     = cellfun(@numel, cc.PixelIdxList);
    [~, idx]  = max(numPx);
    gloveMask = false(h, w);
    gloveMask(cc.PixelIdxList{idx}) = true;

    %Hole detection
    gloveFilled = imfill(gloveMask, 'holes');
    holeMask = gloveFilled & ~gloveMask;

    %Filter false positives
    min_hole_area = 500;
    min_hole_circularity = 0.2;

    holeMask = bwareaopen(holeMask, min_hole_area);
    props = regionprops(holeMask, 'Area', 'Perimeter', 'Centroid', 'BoundingBox');
    keepIdx = false(numel(props), 1);
 
    for k = 1 : numel(props)
    A = props(k).Area;
        P = props(k).Perimeter;
        if P == 0, continue; end
 
        circularity = (4 * pi * A) / (P^2);
        if circularity >= min_hole_circularity
            keepIdx(k) = true;
        end
    end
    validHoles = props(keepIdx);
 
    %Output
    annotated = img;
 
    for k = 1 : numel(validHoles)
        bb  = validHoles(k).BoundingBox;
        cen = validHoles(k).Centroid;

        % Expand box slightly for visibility
        pad = 10;
        x1  = max(1, round(bb(1) - pad));
        y1  = max(1, round(bb(2) - pad));
        x2  = min(w, round(bb(1) + bb(3) + pad));
        y2  = min(h, round(bb(2) + bb(4) + pad));

        % Draw red rectangle by setting border pixels to red
        annotated(y1:y2, x1:x2, 1) = 255;   % R channel
        annotated(y1:y2, x1:x2, 2) = 0;     % G channel
        annotated(y1:y2, x1:x2, 3) = 0;     % B channel

        % Hollow out the inside (only keep the border, 3px thick)
        thickness = 3;
        annotated(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 1) = ...
            img(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 1);
        annotated(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 2) = ...
            img(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 2);
        annotated(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 3) = ...
            img(y1+thickness:y2-thickness, x1+thickness:x2-thickness, 3);
    end

    %Results
    results.defectFound = numel(validHoles) > 0;
    results.numHoles    = numel(validHoles);
    results.holeStats   = validHoles;
    results.annotated   = annotated;
    results.gloveMask   = gloveMask;

    %Debug View (Shows all setps)
    if debugMode
        figure('Name', 'detectHoles — Debug', 'NumberTitle', 'off');
        tiledlayout(2, 3, 'TileSpacing', 'compact');
 
        nexttile; imshow(img);            title('1. Original');
        nexttile; imshow(H);              title('2. Hue Channel');
        nexttile; imshow(gloveMask);      title('3. Glove Mask');
        nexttile; imshow(gloveFilled);    title('4. Filled Mask');
        nexttile; imshow(holeMask);       title('5. Hole Mask');
        nexttile; imshow(annotated);
        title(sprintf('6. Result — %d hole(s)', numel(validHoles)));
    end
 
end