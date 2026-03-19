classdef Glove_GUI < matlab.apps.AppBase

    % Internal state
    properties (Access = private)
        LoadedImage
    end

    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        ControlPanel               matlab.ui.container.Panel
        ImageAxes                  matlab.ui.control.UIAxes
        SelectDefectDropDown       matlab.ui.control.DropDown
        SelectDefectDropDownLabel  matlab.ui.control.Label
        ResultsPanel               matlab.ui.container.Panel
        LatexGloveLabel            matlab.ui.control.Label
        UploadButton               matlab.ui.control.Button
        ApplyDefectsButton         matlab.ui.control.Button
        ShowFiltersUsedButton      matlab.ui.control.Button
        BackButton                 matlab.ui.control.Button
        ForeignObjectLabel         matlab.ui.control.Label
        ForeignObjectCount         matlab.ui.control.Label
        HoleLabel                  matlab.ui.control.Label
        HoleCount                  matlab.ui.control.Label
        ContamLabel                matlab.ui.control.Label
        ContamCount                matlab.ui.control.Label
    end

    methods (Access = private)

        %% ── UPLOAD ───────────────────────────────────────────────────────
        function UploadButtonPushed(app, event)
            [file, path] = uigetfile( ...
                {'*.jpg;*.png;*.bmp;*.tif', 'Image Files'}, ...
                'Select Glove Image');
            if isequal(file, 0), return; end
            app.LoadedImage = imread(fullfile(path, file));
            imshow(app.LoadedImage, 'Parent', app.ImageAxes);
            app.ForeignObjectCount.Text = '-';
            app.HoleCount.Text          = '-';
            app.ContamCount.Text        = '-';
        end

        %% ── APPLY DEFECTS ────────────────────────────────────────────────
        function ApplyDefectsButtonPushed(app, event)
            if isempty(app.LoadedImage)
                uialert(app.UIFigure, 'Please upload an image first.', 'No Image');
                return;
            end

            input_img = app.LoadedImage;
            [img_h, img_w, ~] = size(input_img);

            switch app.SelectDefectDropDown.Value

                case 'Foreign Object'
                    LatexForeignObject(input_img, false);
                    data = load(fullfile(pwd, 'RNvariables.mat'));
                    pic  = load(fullfile(pwd, 'RNpic.mat'));
                    fo_mask = imresize(pic.RL_foreign_mask, [img_h img_w], 'nearest');
                    imshow(input_img, 'Parent', app.ImageAxes);
                    hold(app.ImageAxes, 'on');
                    showMaskOverlay(app, fo_mask, [1 1 0]);
                    drawBoxes(app, data.foreign_objects, 'FO', 'y');
                    hold(app.ImageAxes, 'off');
                    app.ForeignObjectCount.Text = num2str(numel(data.foreign_objects));

                case 'Hole'
                    LatexHole(input_img, false);
                    data = load(fullfile(pwd, 'RNvariables.mat'));
                    pic  = load(fullfile(pwd, 'RNpic.mat'));
                    h_mask = imresize(pic.RNH_hole, [img_h img_w], 'nearest');
                    imshow(input_img, 'Parent', app.ImageAxes);
                    hold(app.ImageAxes, 'on');
                    showMaskOverlay(app, h_mask, [1 0.2 0.2]);
                    drawBoxes(app, data.large_holes, 'H', 'r');
                    hold(app.ImageAxes, 'off');
                    app.HoleCount.Text = num2str(numel(data.large_holes));

                case 'Contamination'
                    LatexContamination(input_img, false);
                    data = load(fullfile(pwd, 'RNvariables.mat'));
                    pic  = load(fullfile(pwd, 'RNpic.mat'));
                    c_mask = imresize(pic.RNC_contamination_mask, [img_h img_w], 'nearest');
                    imshow(input_img, 'Parent', app.ImageAxes);
                    hold(app.ImageAxes, 'on');
                    showMaskOverlay(app, c_mask, [0 0.8 0]);
                    drawBoxes(app, data.large_contamination, 'C', 'g');
                    hold(app.ImageAxes, 'off');
                    app.ContamCount.Text = num2str(numel(data.large_contamination));


            end  % end switch
        end  % end ApplyDefectsButtonPushed  ← THIS WAS MISSING

        %% ── SHOW FILTERS USED ────────────────────────────────────────────
        function ShowFiltersUsedButtonPushed(app, event)
            if isempty(app.LoadedImage)
                uialert(app.UIFigure, 'Please upload an image first.', 'No Image');
                return;
            end
            input_img = app.LoadedImage;
            switch app.SelectDefectDropDown.Value
                case 'Foreign Object'
                    LatexForeignObject(input_img, true);
                case 'Hole'
                    LatexHole(input_img, true);
                case 'Contamination'
                    LatexContamination(input_img, true);
            end
        end  % end ShowFiltersUsedButtonPushed

        %% ── BACK ─────────────────────────────────────────────────────────
        function BackButtonPushed(app, event)
            delete(app);
        end

        %% ── DROPDOWN CHANGED ─────────────────────────────────────────────
        function SelectDefectDropDownValueChanged(app, event)
            if ~isempty(app.LoadedImage)
                imshow(app.LoadedImage, 'Parent', app.ImageAxes);
            end
            app.ForeignObjectCount.Text = '-';
            app.HoleCount.Text          = '-';
            app.ContamCount.Text        = '-';
        end

        %% ── HELPER: mask overlay ─────────────────────────────────────────
        function showMaskOverlay(app, mask, color)
            overlaid = labeloverlay(app.LoadedImage, mask, ...
                       'Colormap', color, 'Transparency', 0.45);
            imshow(overlaid, 'Parent', app.ImageAxes);
        end

        %% ── HELPER: bounding boxes ───────────────────────────────────────
        function drawBoxes(app, defects, label, edgecolor)
            if isempty(defects), return; end
            for i = 1:numel(defects)
                bb = defects(i).BoundingBox;
                rectangle(app.ImageAxes, 'Position', bb, ...
                    'EdgeColor', edgecolor, 'LineWidth', 2);
                text(app.ImageAxes, bb(1), bb(2) - 6, ...
                    sprintf('%s %d', label, i), ...
                    'Color', edgecolor, 'FontSize', 9, ...
                    'FontWeight', 'bold', 'BackgroundColor', 'k', 'Margin', 1);
            end
        end

    end  % end private methods

    %% ── COMPONENT INITIALIZATION ─────────────────────────────────────────
    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 860 520];
            app.UIFigure.Name = 'Latex Glove Defect Detector';

            % Image axes
            app.ImageAxes = uiaxes(app.UIFigure);
            app.ImageAxes.Position = [250 10 600 500];
            app.ImageAxes.XTick = [];
            app.ImageAxes.YTick = [];
            app.ImageAxes.Box   = 'off';

            % Control panel
            app.ControlPanel = uipanel(app.UIFigure);
            app.ControlPanel.Title      = 'Control Panel';
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.FontSize   = 13;
            app.ControlPanel.Position   = [1 1 248 520];

            % Title label
            app.LatexGloveLabel = uilabel(app.ControlPanel);
            app.LatexGloveLabel.HorizontalAlignment = 'center';
            app.LatexGloveLabel.FontSize   = 15;
            app.LatexGloveLabel.FontWeight = 'bold';
            app.LatexGloveLabel.FontColor  = [0.07 0.62 1];
            app.LatexGloveLabel.Position   = [20 470 210 28];
            app.LatexGloveLabel.Text       = 'Latex Glove Detector';

            % Upload button
            app.UploadButton = uibutton(app.ControlPanel, 'push');
            app.UploadButton.ButtonPushedFcn = createCallbackFcn(app, @UploadButtonPushed, true);
            app.UploadButton.BackgroundColor = [0.5 0.5 0.5];
            app.UploadButton.FontWeight = 'bold';
            app.UploadButton.FontColor  = [1 1 1];
            app.UploadButton.FontSize   = 13;
            app.UploadButton.Position   = [44 420 160 40];
            app.UploadButton.Text       = 'Upload Image';

            % Dropdown label
            app.SelectDefectDropDownLabel = uilabel(app.ControlPanel);
            app.SelectDefectDropDownLabel.Position   = [10 375 90 22];
            app.SelectDefectDropDownLabel.Text        = 'Select Defect:';
            app.SelectDefectDropDownLabel.FontWeight  = 'bold';

            % Dropdown
            app.SelectDefectDropDown = uidropdown(app.ControlPanel);
            app.SelectDefectDropDown.Items = {'Foreign Object', 'Hole', 'Contamination'};
            app.SelectDefectDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectDefectDropDownValueChanged, true);
            app.SelectDefectDropDown.FontSize = 12;
            app.SelectDefectDropDown.Position = [104 370 130 30];
            app.SelectDefectDropDown.Value    = 'Foreign Object';

            % Apply Defects button
            app.ApplyDefectsButton = uibutton(app.ControlPanel, 'push');
            app.ApplyDefectsButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyDefectsButtonPushed, true);
            app.ApplyDefectsButton.BackgroundColor = [0.64 0.08 0.18];
            app.ApplyDefectsButton.FontWeight = 'bold';
            app.ApplyDefectsButton.FontSize   = 13;
            app.ApplyDefectsButton.FontColor  = [1 1 1];
            app.ApplyDefectsButton.Position   = [44 320 160 40];
            app.ApplyDefectsButton.Text       = 'Apply Defects';

            % Show Filters button
            app.ShowFiltersUsedButton = uibutton(app.ControlPanel, 'push');
            app.ShowFiltersUsedButton.ButtonPushedFcn = createCallbackFcn(app, @ShowFiltersUsedButtonPushed, true);
            app.ShowFiltersUsedButton.BackgroundColor = [0.18 0.75 0.94];
            app.ShowFiltersUsedButton.FontWeight = 'bold';
            app.ShowFiltersUsedButton.FontSize   = 13;
            app.ShowFiltersUsedButton.FontColor  = [1 1 1];
            app.ShowFiltersUsedButton.Position   = [44 268 160 40];
            app.ShowFiltersUsedButton.Text       = 'Show Filters Used';

            % Results panel
            app.ResultsPanel = uipanel(app.ControlPanel);
            app.ResultsPanel.Title      = 'Defects Detected';
            app.ResultsPanel.FontWeight = 'bold';
            app.ResultsPanel.FontSize   = 12;
            app.ResultsPanel.Position   = [14 80 220 175];

            % Foreign Object row
            app.ForeignObjectLabel = uilabel(app.ResultsPanel);
            app.ForeignObjectLabel.Position  = [10 120 140 22];
            app.ForeignObjectLabel.Text       = 'Foreign Objects:';
            app.ForeignObjectLabel.FontWeight = 'bold';
            app.ForeignObjectCount = uilabel(app.ResultsPanel);
            app.ForeignObjectCount.Position  = [165 120 45 22];
            app.ForeignObjectCount.Text       = '-';
            app.ForeignObjectCount.FontWeight = 'bold';
            app.ForeignObjectCount.FontColor  = [0.8 0.1 0.1];

            % Hole row
            app.HoleLabel = uilabel(app.ResultsPanel);
            app.HoleLabel.Position  = [10 80 140 22];
            app.HoleLabel.Text       = 'Holes:';
            app.HoleLabel.FontWeight = 'bold';
            app.HoleCount = uilabel(app.ResultsPanel);
            app.HoleCount.Position  = [165 80 45 22];
            app.HoleCount.Text       = '-';
            app.HoleCount.FontWeight = 'bold';
            app.HoleCount.FontColor  = [0.8 0.1 0.1];

            % Contamination row
            app.ContamLabel = uilabel(app.ResultsPanel);
            app.ContamLabel.Position  = [10 40 140 22];
            app.ContamLabel.Text       = 'Contamination:';
            app.ContamLabel.FontWeight = 'bold';
            app.ContamCount = uilabel(app.ResultsPanel);
            app.ContamCount.Position  = [165 40 45 22];
            app.ContamCount.Text       = '-';
            app.ContamCount.FontWeight = 'bold';
            app.ContamCount.FontColor  = [0.8 0.1 0.1];

            % Back button
            app.BackButton = uibutton(app.ControlPanel, 'push');
            app.BackButton.ButtonPushedFcn = createCallbackFcn(app, @BackButtonPushed, true);
            app.BackButton.BackgroundColor = [1 0 0];
            app.BackButton.FontWeight = 'bold';
            app.BackButton.FontSize   = 13;
            app.BackButton.FontColor  = [1 1 1];
            app.BackButton.Position   = [14 20 100 40];
            app.BackButton.Text       = 'Back';

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = Glove_GUI
            createComponents(app)
            registerApp(app, app.UIFigure)
            app.LoadedImage = [];
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end