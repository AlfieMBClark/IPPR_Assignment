classdef guiNylon < matlab.apps.AppBase

    % GloveDefectGUI — Glove Defect Detection System
    %
    % USAGE: Type GloveDefectGUI; in the MATLAB command window.
    % All detector .m files must be in the same folder.

    properties (Access = public)
        UIFigure        matlab.ui.Figure
        LeftPanel       matlab.ui.container.Panel
        RightPanel      matlab.ui.container.Panel

        %Controls
        LoadButton      matlab.ui.control.Button
        RunButton       matlab.ui.control.Button
        ResetButton     matlab.ui.control.Button
        FileLabel       matlab.ui.control.Label
        ToggleLabel     matlab.ui.control.Label
        HoleCheckbox    matlab.ui.control.CheckBox
        TipCheckbox     matlab.ui.control.CheckBox
        ThreadCheckbox  matlab.ui.control.CheckBox
        DebugCheckbox   matlab.ui.control.CheckBox

        %Results
        ResultsPanel    matlab.ui.container.Panel
        StatusLabel     matlab.ui.control.Label
        ResultsTextArea matlab.ui.control.TextArea

        %Image display
        OriginalAxes    matlab.ui.control.UIAxes
        ResultAxes      matlab.ui.control.UIAxes
    end

    properties (Access = private)
        CurrentImagePath    string
        CurrentImage        uint8
    end

    methods (Access = private)

        %Load Image Button
        function LoadButtonPushed(app, ~)
            [file, folder] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.bmp', 'Image Files'}, ...
                'Select a glove image');

            if isequal(file, 0), return; end

            app.CurrentImagePath = fullfile(folder, file);

            img = imread(app.CurrentImagePath);
            if max(size(img,1), size(img,2)) > 800
                scale = 800 / max(size(img,1), size(img,2));
                img   = imresize(img, scale);
            end
            app.CurrentImage = img;

            imshow(img, 'Parent', app.OriginalAxes);
            app.OriginalAxes.Title.String = 'Original Image';
            cla(app.ResultAxes);
            app.ResultAxes.Title.String   = 'Result';

            app.FileLabel.Text   = sprintf('File: %s', file);
            app.StatusLabel.Text = 'Image loaded. Press Run to detect.';
            app.StatusLabel.FontColor = [0.2 0.2 0.2];
            app.ResultsTextArea.Value = {''};
            app.RunButton.Enable = true;
        end

        %Run Detection Button
        function RunButtonPushed(app, ~)
            if isempty(app.CurrentImage)
                uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                return;
            end

            app.RunButton.Enable  = false;
            app.LoadButton.Enable = false;
            app.StatusLabel.Text  = 'Running detection...';
            app.StatusLabel.FontColor = [0.8 0.6 0.0];
            drawnow;

            img       = app.CurrentImage;
            combined  = img;
            debugMode = app.DebugCheckbox.Value;
            defectSummary  = {};
            anyDefectFound = false;

            try
                %Hole detection
                if app.HoleCheckbox.Value
                    holeResults = detectNylonHole(img, debugMode);
                    if holeResults.defectFound
                        anyDefectFound = true;
                        defectSummary{end+1} = sprintf('Hole — %d region(s)', ...
                            holeResults.numHoles);
                        combined = layerAnnotations(combined, img, holeResults.annotated);
                    end
                end

                %Missing fingertip detection
                if app.TipCheckbox.Value
                    tipResults = detectNylonMissingFingertip(img, debugMode);
                    if tipResults.defectFound
                        anyDefectFound = true;
                        defectSummary{end+1} = sprintf('Missing Fingertip — %d region(s)', ...
                            tipResults.numDefects);
                        combined = layerAnnotations(combined, img, tipResults.annotated);
                    end
                end

                %Loose thread detection
                if app.ThreadCheckbox.Value
                    threadResults = detectNylonLooseThreads(img, debugMode);
                    if threadResults.defectFound
                        anyDefectFound = true;
                        defectSummary{end+1} = sprintf('Loose Thread — %d region(s)', ...
                            threadResults.numDefects);
                        combined = layerAnnotations(combined, img, threadResults.annotated);
                    end
                end

                %Display result
                imshow(combined, 'Parent', app.ResultAxes);
                axis(app.ResultAxes, 'image');

                if anyDefectFound
                    app.ResultAxes.Title.String = 'Defects Detected';
                    app.StatusLabel.Text        = 'Detection complete — defects found.';
                    app.StatusLabel.FontColor   = [0.8 0.1 0.1];
                    app.ResultsTextArea.Value   = defectSummary;
                else
                    app.ResultAxes.Title.String = 'No Defects Detected';
                    app.StatusLabel.Text        = 'Detection complete — glove OK.';
                    app.StatusLabel.FontColor   = [0.1 0.6 0.1];
                    app.ResultsTextArea.Value   = {'No defects detected.'};
                end

            catch ME
                app.StatusLabel.Text      = 'Error during detection.';
                app.StatusLabel.FontColor = [0.8 0.1 0.1];
                app.ResultsTextArea.Value = {['Error: ' ME.message]};
            end

            app.RunButton.Enable  = true;
            app.LoadButton.Enable = true;
        end

        %Reset Button
        function ResetButtonPushed(app, ~)
            app.CurrentImagePath = "";
            app.CurrentImage     = [];

            cla(app.OriginalAxes);
            cla(app.ResultAxes);
            app.OriginalAxes.Title.String = 'Original Image';
            app.ResultAxes.Title.String   = 'Result';

            app.FileLabel.Text        = 'No file loaded';
            app.StatusLabel.Text      = 'Ready.';
            app.StatusLabel.FontColor = [0.2 0.2 0.2];
            app.ResultsTextArea.Value = {''};
            app.RunButton.Enable      = false;
        end

        %Build UI components
        function createComponents(app)

            %Main figure
            app.UIFigure          = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1100 650];
            app.UIFigure.Name     = 'Glove Defect Detection System';
            app.UIFigure.Color    = [0.15 0.15 0.18];

            %Left control panel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.Position        = [10 10 260 630];
            app.LeftPanel.Title           = 'Controls';
            app.LeftPanel.FontSize        = 13;
            app.LeftPanel.FontWeight      = 'bold';
            app.LeftPanel.ForegroundColor = [1 1 1];
            app.LeftPanel.BackgroundColor = [0.2 0.2 0.24];

            %Load button
            app.LoadButton = uibutton(app.LeftPanel, 'push');
            app.LoadButton.Position         = [15 570 230 38];
            app.LoadButton.Text             = 'Load Image';
            app.LoadButton.FontSize         = 13;
            app.LoadButton.FontWeight       = 'bold';
            app.LoadButton.BackgroundColor  = [0.25 0.50 0.85];
            app.LoadButton.FontColor        = [1 1 1];
            app.LoadButton.ButtonPushedFcn  = @(~,~) app.LoadButtonPushed();

            %File label
            app.FileLabel = uilabel(app.LeftPanel);
            app.FileLabel.Position  = [10 540 240 22];
            app.FileLabel.Text      = 'No file loaded';
            app.FileLabel.FontSize  = 10;
            app.FileLabel.FontColor = [0.7 0.7 0.7];
            app.FileLabel.WordWrap  = 'on';

            %Detectors label
            app.ToggleLabel = uilabel(app.LeftPanel);
            app.ToggleLabel.Position   = [10 505 240 20];
            app.ToggleLabel.Text       = 'Detectors to run:';
            app.ToggleLabel.FontSize   = 11;
            app.ToggleLabel.FontWeight = 'bold';
            app.ToggleLabel.FontColor  = [0.9 0.9 0.9];

            %Hole checkbox
            app.HoleCheckbox = uicheckbox(app.LeftPanel);
            app.HoleCheckbox.Position  = [15 477 230 24];
            app.HoleCheckbox.Text      = 'Hole Detection';
            app.HoleCheckbox.Value     = true;
            app.HoleCheckbox.FontSize  = 12;
            app.HoleCheckbox.FontColor = [1 1 1];

            %Missing tip checkbox
            app.TipCheckbox = uicheckbox(app.LeftPanel);
            app.TipCheckbox.Position  = [15 447 230 24];
            app.TipCheckbox.Text      = 'Missing Fingertip';
            app.TipCheckbox.Value     = true;
            app.TipCheckbox.FontSize  = 12;
            app.TipCheckbox.FontColor = [1 1 1];

            %Thread checkbox
            app.ThreadCheckbox = uicheckbox(app.LeftPanel);
            app.ThreadCheckbox.Position  = [15 417 230 24];
            app.ThreadCheckbox.Text      = 'Loose Thread';
            app.ThreadCheckbox.Value     = true;
            app.ThreadCheckbox.FontSize  = 12;
            app.ThreadCheckbox.FontColor = [1 1 1];

            %Debug checkbox
            app.DebugCheckbox = uicheckbox(app.LeftPanel);
            app.DebugCheckbox.Position  = [15 382 230 24];
            app.DebugCheckbox.Text      = 'Show Debug Figures';
            app.DebugCheckbox.Value     = false;
            app.DebugCheckbox.FontSize  = 11;
            app.DebugCheckbox.FontColor = [0.75 0.75 0.75];

            %Run button
            app.RunButton = uibutton(app.LeftPanel, 'push');
            app.RunButton.Position        = [15 325 230 45];
            app.RunButton.Text            = 'Run Detection';
            app.RunButton.FontSize        = 14;
            app.RunButton.FontWeight      = 'bold';
            app.RunButton.BackgroundColor = [0.15 0.70 0.35];
            app.RunButton.FontColor       = [1 1 1];
            app.RunButton.Enable          = false;
            app.RunButton.ButtonPushedFcn = @(~,~) app.RunButtonPushed();

            %Reset button
            app.ResetButton = uibutton(app.LeftPanel, 'push');
            app.ResetButton.Position        = [15 270 230 38];
            app.ResetButton.Text            = 'Reset';
            app.ResetButton.FontSize        = 12;
            app.ResetButton.BackgroundColor = [0.45 0.45 0.50];
            app.ResetButton.FontColor       = [1 1 1];
            app.ResetButton.ButtonPushedFcn = @(~,~) app.ResetButtonPushed();

            %Results panel
            app.ResultsPanel = uipanel(app.LeftPanel);
            app.ResultsPanel.Position        = [10 10 240 245];
            app.ResultsPanel.Title           = 'Detection Results';
            app.ResultsPanel.FontSize        = 11;
            app.ResultsPanel.FontWeight      = 'bold';
            app.ResultsPanel.ForegroundColor = [1 1 1];
            app.ResultsPanel.BackgroundColor = [0.18 0.18 0.22];

            %Status label
            app.StatusLabel = uilabel(app.ResultsPanel);
            app.StatusLabel.Position   = [5 200 230 22];
            app.StatusLabel.Text       = 'Ready.';
            app.StatusLabel.FontSize   = 11;
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontColor  = [0.2 0.2 0.2];

            %Results text area
            app.ResultsTextArea = uitextarea(app.ResultsPanel);
            app.ResultsTextArea.Position        = [5 5 230 190];
            app.ResultsTextArea.Editable        = false;
            app.ResultsTextArea.FontSize        = 11;
            app.ResultsTextArea.Value           = {''};
            app.ResultsTextArea.BackgroundColor = [0.13 0.13 0.16];
            app.ResultsTextArea.FontColor       = [0.9 0.9 0.9];

            %Right image panel
            app.RightPanel = uipanel(app.UIFigure);
            app.RightPanel.Position        = [280 10 810 630];
            app.RightPanel.Title           = 'Image Viewer';
            app.RightPanel.FontSize        = 13;
            app.RightPanel.FontWeight      = 'bold';
            app.RightPanel.ForegroundColor = [1 1 1];
            app.RightPanel.BackgroundColor = [0.2 0.2 0.24];

            %Original image axes
            app.OriginalAxes = uiaxes(app.RightPanel);
            app.OriginalAxes.Position             = [10 30 390 570];
            app.OriginalAxes.Title.String         = 'Original Image';
            app.OriginalAxes.Title.FontSize       = 12;
            app.OriginalAxes.Title.Color          = [1 1 1];
            app.OriginalAxes.Color                = [0.12 0.12 0.15];
            app.OriginalAxes.XColor               = 'none';
            app.OriginalAxes.YColor               = 'none';

            %Result image axes
            app.ResultAxes = uiaxes(app.RightPanel);
            app.ResultAxes.Position             = [410 30 390 570];
            app.ResultAxes.Title.String         = 'Result';
            app.ResultAxes.Title.FontSize       = 12;
            app.ResultAxes.Title.Color          = [1 1 1];
            app.ResultAxes.Color                = [0.12 0.12 0.15];
            app.ResultAxes.XColor               = 'none';
            app.ResultAxes.YColor               = 'none';

        end

    end

    methods (Access = public)

        function app = guiNylon
            createComponents(app);
            registerApp(app, app.UIFigure);
            app.UIFigure.Visible = 'on';
        end

        function delete(app)
            delete(app.UIFigure);
        end

    end

end