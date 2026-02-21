classdef RubberNutrile_GUI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
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
        text2        matlab.ui.control.Label
        pushbutton1  matlab.ui.control.Button
        axes1        matlab.ui.control.UIAxes
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: pushbutton1
        function LoadButtonButtonPushed(app, event)
            % Reset defect counters
            app.text6.Text = '0';
            app.text7.Text = '0';
            app.text8.Text = '0';

            [File_Name, Path_Name] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'Image Files (*.jpg, *.png, *.bmp, *.tif)'}, 'Select image');
            if isequal(File_Name, 0)
                return;
            end
            fullname = fullfile(Path_Name, File_Name);
            im = imread(fullname);
            imshow(im, 'Parent', app.axes1);
        end

        % Button pushed function: back
        function backButtonPushed(app, event)
            % Close this GUI
            delete(app);
        end

        % Button pushed function: pushbutton3
        function DetectButton3ButtonPushed(app, event)
            input = getimage(app.axes1);
            if isempty(input)
                uialert(app.UIFigure, 'Please load an image first.', 'No Image');
                return;
            end

            switch app.popupmenu1.Value
                case 'Missing Finger'
                    RubberFinger(input);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text6.Text = num2str(numel(count.LMissingFinger));
                    imshow(input, 'Parent', app.axes1);
                    for i = 1:numel(count.LMissingFinger)
                        bbox = count.LMissingFinger(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
                    end

                case 'Hole'
                    RubberHole(input);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text7.Text = num2str(numel(count.large_holes));
                    imshow(input, 'Parent', app.axes1);
                    for i = 1:numel(count.large_holes)
                        bbox = count.large_holes(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
                    end

                case 'Stain'
                    RubberStain(input);
                    count = load(fullfile(pwd, 'RNvariables.mat'));
                    app.text8.Text = num2str(numel(count.large_stains));
                    imshow(input, 'Parent', app.axes1);
                    for i = 1:numel(count.large_stains)
                        bbox = count.large_stains(i).BoundingBox;
                        rectangle(app.axes1, 'Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
                    end
            end
        end

        % Button pushed function: pushbutton6
        function ShowMaskbutton6ButtonPushed(app, event)
            switch app.popupmenu1.Value
                case 'Missing Finger'
                    picture = load(fullfile(pwd, 'RNpic.mat'));
                    figure('Name', 'Masks');
                    subplot(131); imshow(picture.foreground_mask); title('Foreground Mask');
                    subplot(132); imshow(picture.skin_mask); title('Skin Mask');
                    subplot(133); imshow(picture.RN_missingfinger); title('Final Mask');

                case 'Hole'
                    picture = load(fullfile(pwd, 'RNpic.mat'));
                    figure('Name', 'Masks');
                    subplot(131); imshow(picture.RNH_filledMask); title('Filled Mask');
                    subplot(132); imshow(picture.RNH_DefectMask); title('Defect Mask');
                    subplot(133); imshow(picture.RNH_hole); title('Final Mask');

                case 'Stain'
                    picture = load(fullfile(pwd, 'RNpic.mat'));
                    figure('Name', 'Masks');
                    subplot(131); imshow(picture.RNS_glove_mask); title('Glove Mask');
                    subplot(132); imshow(picture.RNS_defect_mask); title('Defect Mask');
                    subplot(133); imshow(picture.RNS_stain_mask); title('Final Mask');
            end
        end

        % Value changed function: popupmenu1
        function popupmenu1ValueChanged(app, event)
            % Reserved for future use
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1167 768];
            app.UIFigure.Name = 'MATLAB App';

            % Create axes1
            app.axes1 = uiaxes(app.UIFigure);
            app.axes1.FontSize = 10;
            app.axes1.NextPlot = 'replace';
            app.axes1.Tag = 'axes1';
            app.axes1.Position = [444 30 677 723];

            % Create uipanel1
            app.uipanel1 = uipanel(app.UIFigure);
            app.uipanel1.TitlePosition = 'centertop';
            app.uipanel1.Title = 'Control Panel';
            app.uipanel1.BackgroundColor = [1 1 1];
            app.uipanel1.Tag = 'uipanel1';
            app.uipanel1.FontWeight = 'bold';
            app.uipanel1.FontSize = 18;
            app.uipanel1.Position = [0 39 445 705];

            % Create pushbutton1
            app.pushbutton1 = uibutton(app.uipanel1, 'push');
            app.pushbutton1.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonButtonPushed, true);
            app.pushbutton1.Tag = 'pushbutton1';
            app.pushbutton1.BackgroundColor = [0.651 0.651 0.651];
            app.pushbutton1.FontSize = 14;
            app.pushbutton1.FontWeight = 'bold';
            app.pushbutton1.FontColor = [1 1 1];
            app.pushbutton1.Position = [31 464 216 123];
            app.pushbutton1.Text = 'Upload Image';

            % Create text2
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

            % Create pushbutton3
            app.pushbutton3 = uibutton(app.uipanel1, 'push');
            app.pushbutton3.ButtonPushedFcn = createCallbackFcn(app, @DetectButton3ButtonPushed, true);
            app.pushbutton3.Tag = 'pushbutton3';
            app.pushbutton3.BackgroundColor = [0.6353 0.0784 0.1843];
            app.pushbutton3.FontSize = 14;
            app.pushbutton3.FontWeight = 'bold';
            app.pushbutton3.FontColor = [1 1 1];
            app.pushbutton3.Position = [116 341 214 76];
            app.pushbutton3.Text = 'Apply Defects';

            % Create uipanel2
            app.uipanel2 = uipanel(app.uipanel1);
            app.uipanel2.ForegroundColor = [0.0745 0.6235 1];
            app.uipanel2.Title = 'Defects Detected:';
            app.uipanel2.BackgroundColor = [1 1 1];
            app.uipanel2.Tag = 'uipanel2';
            app.uipanel2.FontWeight = 'bold';
            app.uipanel2.FontSize = 24;
            app.uipanel2.Position = [17 86 409 214];

            % Create Hole
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

            % Create text4
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

            % Create text5
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

            % Create text6
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

            % Create text7
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

            % Create text8
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

            % Create back
            app.back = uibutton(app.uipanel1, 'push');
            app.back.ButtonPushedFcn = createCallbackFcn(app, @backButtonPushed, true);
            app.back.Tag = 'back';
            app.back.BackgroundColor = [1 0 0];
            app.back.FontSize = 14;
            app.back.FontWeight = 'bold';
            app.back.FontColor = [1 1 1];
            app.back.Position = [22 9 80 51];
            app.back.Text = 'Back';

            % Create pushbutton6
            app.pushbutton6 = uibutton(app.uipanel1, 'push');
            app.pushbutton6.ButtonPushedFcn = createCallbackFcn(app, @ShowMaskbutton6ButtonPushed, true);
            app.pushbutton6.Tag = 'pushbutton6';
            app.pushbutton6.BackgroundColor = [0.0745 0.6235 1];
            app.pushbutton6.FontSize = 14;
            app.pushbutton6.FontColor = [1 1 1];
            app.pushbutton6.Position = [201 9 216 51];
            app.pushbutton6.Text = 'Show Masks';

            % Create popupmenu1
            app.popupmenu1 = uidropdown(app.uipanel1);
            app.popupmenu1.Items = {'Missing Finger', 'Hole', 'Stain'};
            app.popupmenu1.ValueChangedFcn = createCallbackFcn(app, @popupmenu1ValueChanged, true);
            app.popupmenu1.Tag = 'popupmenu1';
            app.popupmenu1.FontSize = 18;
            app.popupmenu1.BackgroundColor = [1 1 1];
            app.popupmenu1.Position = [265 487 152 35];
            app.popupmenu1.Value = 'Missing Finger';

            % Create text2_2
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

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = RubberNutrile_GUI_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end