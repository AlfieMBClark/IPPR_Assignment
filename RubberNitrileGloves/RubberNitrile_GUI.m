classdef RubberNitrile_GUI < matlab.apps.AppBase

    % mask toggle
    properties (Access = private)
        MaskVisible  logical = false 
        OriginalImage              % clean detect img
        RunAllMasks struct = struct('missing', [], 'hole', [], 'stain', [])
        RunAllDefects struct = struct('missing', [], 'hole', [], 'stain', [])
    end

    % Property app components
    properties (Access = public)
        UIFigure     matlab.ui.Figure
        uipanel1     matlab.ui.container.Panel
        text2_2      matlab.ui.control.Label
        popupmenu1   matlab.ui.control.DropDown
        pushbutton6  matlab.ui.control.Button
        back         matlab.ui.control.Button
        uipanel2     matlab.ui.container.Panel
        text8        matlab.ui.control.Label
        text7        matlab.ui.control.Label
        text6        matlab.ui.control.Label
        text5        matlab.ui.control.Label
        text4        matlab.ui.control.Label
        Hole         matlab.ui.control.Label
        pushbutton3  matlab.ui.control.Button
        showStepsBtn matlab.ui.control.Button
        text2        matlab.ui.control.Label
        pushbutton1  matlab.ui.control.Button
        axes1        matlab.ui.control.UIAxes
    end

    %component events
    methods (Access = private)

        function LoadButtonButtonPushed(app, event)
            % Reset defect counters
            app.text6.Text = '0';
            app.text7.Text = '0';
            app.text8.Text = '0';
            % Reset mask tgl
            app.MaskVisible = false;
            app.OriginalImage = [];
            app.RunAllMasks = struct('missing', [], 'hole', [], 'stain', []);
            app.RunAllDefects = struct('missing', [], 'hole', [], 'stain', []);
            app.pushbutton6.Text = 'Show Masks';
            app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];

            [File_Name, Path_Name] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files (*.jpg, *.png, *.bmp, *.tif)'}, 'Select image');
            if isequal(File_Name, 0)
                return;
            end
            fullname = fullfile(Path_Name, File_Name);
            im = imread(fullname);

            % Resize for display for img
            try
                pos = app.axes1.Position; % [left bottom width height]
                targetW = max(1, round(pos(3)));
                targetH = max(1, round(pos(4)));
                imH = size(im, 1);
                imW = size(im, 2);
                scale = min(1, min(targetH / imH, targetW / imW));
                if scale < 1
                    im = imresize(im, scale, 'bicubic');
                end
            catch
                %original image if err
            end

            imshow(im, 'Parent', app.axes1, 'InitialMagnification', 'fit');
        end

        % back btn
        function backButtonPushed(app, event)
            % Close this GUI and return to the main menu page
            delete(app);
            MainMenu();
        end

        %Detect btn
        function DetectButton3ButtonPushed(app, event)
            input = getimage(app.axes1);
            if isempty(input)
                uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                return;
            end
            % Reset mask
            app.MaskVisible = false;
            app.OriginalImage = [];
            app.RunAllMasks = struct('missing', [], 'hole', [], 'stain', []);
            app.RunAllDefects = struct('missing', [], 'hole', [], 'stain', []);
            app.pushbutton6.Text = 'Show Masks';
            app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];

            switch app.popupmenu1.Value
                case 'Missing Finger'
                    RubberFinger(input, false);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text6.Text = num2str(numel(count.LMissingFinger));
                    imshow(input, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                    for i = 1:numel(count.LMissingFinger)
                        bbox = count.LMissingFinger(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0 0], 'LineWidth', 2);
                    end

                case 'Hole'
                    RubberHole(input, false);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text7.Text = num2str(numel(count.large_holes));
                    imshow(input, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                    for i = 1:numel(count.large_holes)
                        bbox = count.large_holes(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0.65 0], 'LineWidth', 2);
                    end

                case 'Stain'
                    RubberStain(input, false);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text8.Text = num2str(numel(count.large_stains));
                    imshow(input, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                    for i = 1:numel(count.large_stains)
                        bbox = count.large_stains(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [0.2 0.9 1], 'LineWidth', 2);
                    end

                case 'Run all'
                    % Missing Finger
                    RubberFinger(input, false);
                    mfVars = load(fullfile(pwd, 'RNvariables.mat'));
                    mfPic = load(fullfile(pwd, 'RNpic.mat'));
                    missingDefects = mfVars.LMissingFinger;
                    missingMask = mfPic.RN_missingfinger;

                    % Hole
                    RubberHole(input, false);
                    hVars = load(fullfile(pwd, 'RNvariables.mat'));
                    hPic = load(fullfile(pwd, 'RNpic.mat'));
                    holeDefects = hVars.large_holes;
                    holeMask = hPic.RNH_hole;

                    % Stain
                    RubberStain(input, false);
                    sVars = load(fullfile(pwd, 'RNvariables.mat'));
                    sPic = load(fullfile(pwd, 'RNpic.mat'));
                    stainDefects = sVars.large_stains;
                    stainMask = sPic.RNS_stain_mask;

                    %counters
                    app.text6.Text = num2str(numel(missingDefects));
                    app.text7.Text = num2str(numel(holeDefects));
                    app.text8.Text = num2str(numel(stainDefects));

                    %Cache run-all data for mask overlay
                    app.RunAllMasks = struct('missing', missingMask, 'hole', holeMask, 'stain', stainMask);
                    app.RunAllDefects = struct('missing', missingDefects, 'hole', holeDefects, 'stain', stainDefects);

                    %draw detections
                    imshow(input, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                    hold(app.axes1, 'on');
                    for i = 1:numel(missingDefects)
                        bbox = missingDefects(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0 0], 'LineWidth', 2);
                        text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Missing Finger %d', i), ...
                             'Color', [1 0 0], 'FontSize', 10, 'FontWeight', 'bold', ...
                             'BackgroundColor', 'white', 'Margin', 2);
                    end
                    for i = 1:numel(holeDefects)
                        bbox = holeDefects(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0.65 0], 'LineWidth', 2);
                        text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Hole %d', i), ...
                             'Color', [1 0.4 0], 'FontSize', 10, 'FontWeight', 'bold', ...
                             'BackgroundColor', 'white', 'Margin', 2);
                    end
                    for i = 1:numel(stainDefects)
                        bbox = stainDefects(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [0.2 0.9 1], 'LineWidth', 2);
                        text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Stain %d', i), ...
                             'Color', [0 0.5 0.8], 'FontSize', 10, 'FontWeight', 'bold', ...
                             'BackgroundColor', 'white', 'Margin', 2);
                    end
                    hold(app.axes1, 'off');
            end
        end

        %show mask btn
        function ShowMaskbutton6ButtonPushed(app, event)
            if strcmp(app.popupmenu1.Value, 'Run all')
                if app.MaskVisible
                    app.MaskVisible = false;
                    app.pushbutton6.Text = 'Show Masks';
                    app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];
                    if ~isempty(app.OriginalImage)
                        imshow(app.OriginalImage, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                        hold(app.axes1, 'on');
                        defects = app.RunAllDefects;
                        for i = 1:numel(defects.missing)
                            bbox = defects.missing(i).BoundingBox;
                            rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0 0], 'LineWidth', 2);
                            text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Missing Finger %d', i), ...
                                 'Color', [1 0 0], 'FontSize', 10, 'FontWeight', 'bold', ...
                                 'BackgroundColor', 'white', 'Margin', 2);
                        end
                        for i = 1:numel(defects.hole)
                            bbox = defects.hole(i).BoundingBox;
                            rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [1 0.65 0], 'LineWidth', 2);
                            text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Hole %d', i), ...
                                 'Color', [1 0.4 0], 'FontSize', 10, 'FontWeight', 'bold', ...
                                 'BackgroundColor', 'white', 'Margin', 2);
                        end
                        for i = 1:numel(defects.stain)
                            bbox = defects.stain(i).BoundingBox;
                            rectangle(app.axes1, 'Position', bbox, 'EdgeColor', [0.2 0.9 1], 'LineWidth', 2);
                            text(app.axes1, bbox(1), bbox(2) - 8, sprintf('Stain %d', i), ...
                                 'Color', [0 0.5 0.8], 'FontSize', 10, 'FontWeight', 'bold', ...
                                 'BackgroundColor', 'white', 'Margin', 2);
                        end
                        hold(app.axes1, 'off');
                    end
                    return;
                end

                % Toggle ON apply all masks overlay
                if isempty(app.RunAllMasks.missing) && isempty(app.RunAllMasks.hole) && isempty(app.RunAllMasks.stain)
                    uialert(app.UIFigure, 'No run-all results found. Run "Apply Defects" with "Run all" selected first.', 'No Results');
                    return;
                end

                input = getimage(app.axes1);
                if isempty(input)
                    uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                    return;
                end

                app.OriginalImage = input;
                app.MaskVisible = true;
                app.pushbutton6.Text = 'Hide Masks';
                app.pushbutton6.BackgroundColor = [0.9294 0.6902 0.1294];

                overlaid = input;
                if ~isempty(app.RunAllMasks.missing)
                    overlaid = labeloverlay(overlaid, app.RunAllMasks.missing, 'Colormap', [0.1176 0.5647 1], 'Transparency', 0.45);
                end
                if ~isempty(app.RunAllMasks.hole)
                    overlaid = labeloverlay(overlaid, app.RunAllMasks.hole, 'Colormap', [1 0.65 0], 'Transparency', 0.45);
                end
                if ~isempty(app.RunAllMasks.stain)
                    overlaid = labeloverlay(overlaid, app.RunAllMasks.stain, 'Colormap', [0.2 0.9 1], 'Transparency', 0.45);
                end

                imshow(overlaid, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                return;
            end

            if ~isfile(fullfile(pwd, 'RNpic.mat')) || ~isfile(fullfile(pwd, 'RNvariables.mat'))
                uialert(app.UIFigure, 'No detection results found. Run "Apply Defects" first.', 'No Results');
                return;
            end

            % Toggle mask OFF
            if app.MaskVisible
                app.MaskVisible = false;
                app.pushbutton6.Text = 'Show Masks';
                app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];
                if ~isempty(app.OriginalImage)
                    imshow(app.OriginalImage, 'Parent', app.axes1, 'InitialMagnification', 'fit');
                    %bounding boxes without mask
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    hold(app.axes1, 'on');
                    switch app.popupmenu1.Value
                        case 'Missing Finger'
                            defects = count.LMissingFinger;
                            label = 'Missing Finger';
                            boxColor = [1 0 0];
                            textColor = [1 0 0];
                        case 'Hole'
                            defects = count.large_holes;
                            label = 'Hole';
                            boxColor = [1 0.65 0];
                            textColor = [1 0.4 0];
                        case 'Stain'
                            defects = count.large_stains;
                            label = 'Stain';
                            boxColor = [0.2 0.9 1];
                            textColor = [0 0.5 0.8];
                    end
                    for i = 1:numel(defects)
                        bbox = defects(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', boxColor, 'LineWidth', 2);
                        text(app.axes1, bbox(1), bbox(2) - 8, sprintf('%s %d', label, i), ...
                             'Color', textColor, 'FontSize', 11, 'FontWeight', 'bold', ...
                             'BackgroundColor', 'white', 'Margin', 2);
                    end
                    hold(app.axes1, 'off');
                end
                return;
            end

            % Toggle ON — apply mask overlay
            input = getimage(app.axes1);
            if isempty(input)
                uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                return;
            end

            picture = load(fullfile(pwd, 'RNpic.mat'));
            count   = load(fullfile(pwd, 'RNvariables.mat'));

            switch app.popupmenu1.Value
                case 'Missing Finger'
                    mask    = picture.RN_missingfinger;
                    defects = count.LMissingFinger;
                    label   = 'Missing Finger';
                    boxColor = [1 0 0];
                    textColor = [1 0 0];
                case 'Hole'
                    mask    = picture.RNH_hole;
                    defects = count.large_holes;
                    label   = 'Hole';
                    boxColor = [1 0.65 0];
                    textColor = [1 0.4 0];
                case 'Stain'
                    mask    = picture.RNS_stain_mask;
                    defects = count.large_stains;
                    label   = 'Stain';
                    boxColor = [0.2 0.9 1];
                    textColor = [0 0.5 0.8];
            end

            %clean image before overlay
            app.OriginalImage = input;
            app.MaskVisible   = true;
            app.pushbutton6.Text = 'Hide Masks';
            app.pushbutton6.BackgroundColor = [0.9294 0.6902 0.1294];

            overlaid = labeloverlay(input, mask, 'Colormap', [0.1176 0.5647 1], 'Transparency', 0.45);
            imshow(overlaid, 'Parent', app.axes1, 'InitialMagnification', 'fit');
    
        end

        %swho steps btn
        function ShowStepsButtonPushed(app, event)
            input = getimage(app.axes1);
            if isempty(input)
                uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                return;
            end

            switch app.popupmenu1.Value
                case 'Missing Finger'
                    RubberFinger(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text6.Text = num2str(numel(count.LMissingFinger));

                case 'Hole'
                    RubberHole(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text7.Text = num2str(numel(count.large_holes));

                case 'Stain'
                    RubberStain(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text8.Text = num2str(numel(count.large_stains));

                case 'Run all'
                    RubberFinger(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text6.Text = num2str(numel(count.LMissingFinger));

                    RubberHole(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text7.Text = num2str(numel(count.large_holes));

                    RubberStain(input, true);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text8.Text = num2str(numel(count.large_stains));
            end
        end


        function popupmenu1ValueChanged(app, event)
        end
    end

    % Component init
    methods (Access = private)
        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1167 768];
            app.UIFigure.Name = 'MATLAB App';
            app.axes1 = uiaxes(app.UIFigure);
            app.axes1.FontSize = 10;
            app.axes1.NextPlot = 'replace';
            app.axes1.Tag = 'axes1';
            app.axes1.Position = [444 30 677 723];
            app.uipanel1 = uipanel(app.UIFigure);
            app.uipanel1.TitlePosition = 'centertop';
            app.uipanel1.Title = 'Control Panel';
            app.uipanel1.BackgroundColor = [1 1 1];
            app.uipanel1.Tag = 'uipanel1';
            app.uipanel1.FontWeight = 'bold';
            app.uipanel1.FontSize = 18;
            app.uipanel1.Position = [0 39 445 705];

            %uploadimg
            app.pushbutton1 = uibutton(app.uipanel1, 'push');
            app.pushbutton1.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonButtonPushed, true);
            app.pushbutton1.Tag = 'pushbutton1';
            app.pushbutton1.BackgroundColor = [0.651 0.651 0.651];
            app.pushbutton1.FontSize = 14;
            app.pushbutton1.FontWeight = 'bold';
            app.pushbutton1.FontColor = [1 1 1];
            app.pushbutton1.Position = [31 464 216 123];
            app.pushbutton1.Text = 'Upload Image';

            %ttitle
            app.text2 = uilabel(app.uipanel1);
            app.text2.Tag = 'text2';
            app.text2.BackgroundColor = [1 1 1];
            app.text2.HorizontalAlignment = 'center';
            app.text2.VerticalAlignment = 'top';
            app.text2.WordWrap = 'on';
            app.text2.FontSize = 24;
            app.text2.FontWeight = 'bold';
            app.text2.FontColor = [0.0745 0.6235 1];
            app.text2.Position = [19 618 406 45];
            app.text2.Text = 'Rubber Nutrile Gloves';

            %applydefect
            app.pushbutton3 = uibutton(app.uipanel1, 'push');
            app.pushbutton3.ButtonPushedFcn = createCallbackFcn(app, @DetectButton3ButtonPushed, true);
            app.pushbutton3.Tag = 'pushbutton3';
            app.pushbutton3.BackgroundColor = [0.6353 0.0784 0.1843];
            app.pushbutton3.FontSize = 14;
            app.pushbutton3.FontWeight = 'bold';
            app.pushbutton3.FontColor = [1 1 1];
            app.pushbutton3.Position = [116 360 214 57];
            app.pushbutton3.Text = 'Apply Defects';

            %stepsbtn
            app.showStepsBtn = uibutton(app.uipanel1, 'push');
            app.showStepsBtn.ButtonPushedFcn = createCallbackFcn(app, @ShowStepsButtonPushed, true);
            app.showStepsBtn.Tag = 'showStepsBtn';
            app.showStepsBtn.BackgroundColor = [0.1529 0.6824 0.3765];
            app.showStepsBtn.FontSize = 13;
            app.showStepsBtn.FontWeight = 'bold';
            app.showStepsBtn.FontColor = [1 1 1];
            app.showStepsBtn.Position = [116 315 214 40];
            app.showStepsBtn.Text = 'Show Steps';

            %detected title
            app.uipanel2 = uipanel(app.uipanel1);
            app.uipanel2.ForegroundColor = [0.0745 0.6235 1];
            app.uipanel2.Title = 'Defects Detected:';
            app.uipanel2.BackgroundColor = [1 1 1];
            app.uipanel2.Tag = 'uipanel2';
            app.uipanel2.FontWeight = 'bold';
            app.uipanel2.FontSize = 24;
            app.uipanel2.Position = [17 86 409 214];

            %Hole
            app.Hole = uilabel(app.uipanel2);
            app.Hole.Tag = 'Hole';
            app.Hole.BackgroundColor = [1 1 1];
            app.Hole.HorizontalAlignment = 'center';
            app.Hole.WordWrap = 'on';
            app.Hole.FontSize = 18;
            app.Hole.FontWeight = 'bold';
            app.Hole.FontColor = [0.149 0.149 0.149];
            app.Hole.Position = [21 117 160 44];
            app.Hole.Text = 'Missing Finger:';

            %output hole
            app.text4 = uilabel(app.uipanel2);
            app.text4.Tag = 'text4';
            app.text4.BackgroundColor = [1 1 1];
            app.text4.HorizontalAlignment = 'center';
            app.text4.WordWrap = 'on';
            app.text4.FontSize = 18;
            app.text4.FontWeight = 'bold';
            app.text4.FontColor = [0.149 0.149 0.149];
            app.text4.Position = [29 70 144 34];
            app.text4.Text = 'Holes:';

            %output stain
            app.text5 = uilabel(app.uipanel2);
            app.text5.Tag = 'text5';
            app.text5.BackgroundColor = [1 1 1];
            app.text5.HorizontalAlignment = 'center';
            app.text5.WordWrap = 'on';
            app.text5.FontSize = 18;
            app.text5.FontWeight = 'bold';
            app.text5.FontColor = [0.149 0.149 0.149];
            app.text5.Position = [46 23 110 27];
            app.text5.Text = 'Stain:';

            %count
            app.text6 = uilabel(app.uipanel2);
            app.text6.Tag = 'text6';
            app.text6.BackgroundColor = [1 1 1];
            app.text6.HorizontalAlignment = 'center';
            app.text6.WordWrap = 'on';
            app.text6.FontSize = 24;
            app.text6.FontWeight = 'bold';
            app.text6.FontColor = [0.6353 0.0784 0.1843];
            app.text6.Position = [207 123 106 33];
            app.text6.Text = '0';

            %count
            app.text7 = uilabel(app.uipanel2);
            app.text7.Tag = 'text7';
            app.text7.BackgroundColor = [1 1 1];
            app.text7.HorizontalAlignment = 'center';
            app.text7.WordWrap = 'on';
            app.text7.FontSize = 24;
            app.text7.FontWeight = 'bold';
            app.text7.FontColor = [0.6353 0.0784 0.1843];
            app.text7.Position = [207 67 106 33];
            app.text7.Text = '0';

            %count
            app.text8 = uilabel(app.uipanel2);
            app.text8.Tag = 'text8';
            app.text8.BackgroundColor = [1 1 1];
            app.text8.HorizontalAlignment = 'center';
            app.text8.WordWrap = 'on';
            app.text8.FontSize = 24;
            app.text8.FontWeight = 'bold';
            app.text8.FontColor = [0.6353 0.0784 0.1843];
            app.text8.Position = [207 20 106 33];
            app.text8.Text = '0';

            %back btn
            app.back = uibutton(app.uipanel1, 'push');
            app.back.ButtonPushedFcn = createCallbackFcn(app, @backButtonPushed, true);
            app.back.Tag = 'back';
            app.back.BackgroundColor = [1 0 0];
            app.back.FontSize = 14;
            app.back.FontWeight = 'bold';
            app.back.FontColor = [1 1 1];
            app.back.Position = [22 9 80 51];
            app.back.Text = 'Back';

            %mask btn
            app.pushbutton6 = uibutton(app.uipanel1, 'push');
            app.pushbutton6.ButtonPushedFcn = createCallbackFcn(app, @ShowMaskbutton6ButtonPushed, true);
            app.pushbutton6.Tag = 'pushbutton6';
            app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];
            app.pushbutton6.FontSize = 14;
            app.pushbutton6.FontColor = [1 1 1];
            app.pushbutton6.Position = [201 9 216 51];
            app.pushbutton6.Text = 'Show Masks';

            %defect menu
            app.popupmenu1 = uidropdown(app.uipanel1);
            app.popupmenu1.Items = {'Missing Finger', 'Hole', 'Stain', 'Run all'};
            app.popupmenu1.ValueChangedFcn = createCallbackFcn(app, @popupmenu1ValueChanged, true);
            app.popupmenu1.Tag = 'popupmenu1';
            app.popupmenu1.FontSize = 18;
            app.popupmenu1.BackgroundColor = [1 1 1];
            app.popupmenu1.Position = [265 487 152 35];
            app.popupmenu1.Value = 'Missing Finger';

            %select text
            app.text2_2 = uilabel(app.uipanel1);
            app.text2_2.Tag = 'text2';
            app.text2_2.BackgroundColor = [1 1 1];
            app.text2_2.VerticalAlignment = 'top';
            app.text2_2.WordWrap = 'on';
            app.text2_2.FontSize = 20;
            app.text2_2.FontWeight = 'bold';
            app.text2_2.FontColor = [1 0.4118 0.1608];
            app.text2_2.Position = [265 540 87 27];
            app.text2_2.Text = ' Select:';

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)
        function app = RubberNitrile_GUI
            createComponents(app)
            registerApp(app, app.UIFigure)
            if nargout == 0
                clear app
            end
        end
        function delete(app)
            delete(app.UIFigure)
        end
    end
end