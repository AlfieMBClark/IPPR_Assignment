function MainMenu()
    fig = uifigure('Name', 'Glove Detection - Main Menu', 'Position', [500 220 600 430], 'Color', [0.96 0.97 0.99]);

    uilabel(fig, 'Text', 'Select Glove Type', 'FontSize', 28, 'FontWeight', 'bold', 'FontColor', [0.08 0.23 0.45], 'HorizontalAlignment', 'center', 'Position', [160 355 280 42]);
    uilabel(fig, 'Text', 'Choose a glove material to continue', 'FontSize', 14, 'FontColor', [0.33 0.37 0.42], 'HorizontalAlignment', 'center','Position', [165 326 270 24]);

    btnW = 200;
    btnH = 56;
    x1 = 95;
    x2 = x1 + btnW + 5;
    y1 = 220;
    y2 = y1 - btnH - 5;

    %btns
    uibutton(fig, 'push', 'Text', 'Rubber Nitrile', 'FontSize', 16, 'FontWeight', 'bold', 'BackgroundColor', [0.10 0.10 0.10], 'FontColor', [1 1 1], 'Position', [x1 y1 btnW btnH], 'ButtonPushedFcn', @openRubberNitrile);
    uibutton(fig, 'push', 'Text', 'Latex', 'FontSize', 16, 'FontWeight', 'bold', 'BackgroundColor', [0.86 0.18 0.18], 'FontColor', [1 1 1], 'Position', [x2 y1 btnW btnH], 'ButtonPushedFcn', @openLatex);
    uibutton(fig, 'push', 'Text', 'Nylon', 'FontSize', 16, 'FontWeight', 'bold', 'BackgroundColor', [0.12 0.42 0.90], 'FontColor', [1 1 1], 'Position', [x1 y2 btnW btnH], 'ButtonPushedFcn', @(~,~)showComingSoon('Nylon'));
    uibutton(fig, 'push', 'Text', 'Cloth', 'FontSize', 16, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1], 'FontColor', [0.10 0.10 0.10], 'Position', [x2 y2 btnW btnH], 'ButtonPushedFcn', @(~,~)showComingSoon('Cloth'));
    uibutton(fig, 'push', 'Text', 'Close', 'FontSize', 13, 'BackgroundColor', [1 0 0], 'FontColor', [1 1 1], 'Position', [255 48 90 32], 'ButtonPushedFcn', @(~,~)delete(fig));

    function openRubberNitrile(~, ~)
        try
            addpath(pwd);  % Parent directory
            rubberPath = fullfile(pwd, 'RubberNitrileGloves');
            addpath(rubberPath);
            app = RubberNitrile_GUI();
            % Del menu
            delete(fig);
        catch ME
            uialert(fig, sprintf('Error launching Rubber Nitrile GUI:\n%s', ME.message), 'Error');
        end
    end

    function openLatex(~, ~)
        try
            addpath(pwd); 
            latexPath = fullfile(pwd, 'LatexGloves');
            addpath(latexPath);
            app = idkGlove_GUI();
            delete(fig);
        catch ME
            uialert(fig, sprintf('Error launching Latex GUI:\n%s', ME.message), 'Error');
        end
    end

    function showComingSoon(gloveType)
        uialert(fig, sprintf('%s module is not connected yet.', gloveType), 'Coming Soon');
    end
end
