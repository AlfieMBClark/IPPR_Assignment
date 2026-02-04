function MainMenu()
    % MAINMENU - Rubber Nitrile Glove Defect Detection System
    % Main menu interface for selecting and running different defect detectors
    
    clc;
    
    % Display welcome banner
    fprintf('\n========================================\n');
    fprintf('  RUBBER NITRILE GLOVE DEFECT DETECTOR\n');
    fprintf('========================================\n\n');
    
    % Main menu loop
    while true
        fprintf('Select a defect detection method:\n');
        fprintf('  1. Hole Detection\n');
        fprintf('  2. Stain Detection\n');
        fprintf('  3. Missing Finger Detection\n');
        fprintf('  4. Run All Detectors\n');
        fprintf('  5. Exit\n\n');
        
        choice = input('Enter your choice (1-5): ', 's');
        
        switch choice
            case '1'
                runHoleDetection();
            case '2'
                runStainDetection();
            case '3'
                runMissingFingerDetection();
            case '4'
                runAllDetectors();
            case '5'
                fprintf('\nExiting program. Goodbye!\n\n');
                break;
            otherwise
                fprintf('\nInvalid choice. Please enter a number between 1 and 5.\n\n');
        end
    end
end

function runHoleDetection()
    fprintf('\n--- Hole Detection ---\n');
    img = selectImage();
    if ~isempty(img)
        fprintf('Running hole detection...\n');
        RubberHole(img);
        fprintf('Results displayed and saved to RNpic.mat and RNvariables.mat\n\n');
    end
end

function runStainDetection()
    fprintf('\n--- Stain Detection ---\n');
    img = selectImage();
    if ~isempty(img)
        fprintf('Running stain detection...\n');
        RubberStain(img);
        fprintf('Results displayed and saved to RNpic.mat and RNvariables.mat\n\n');
    end
end

function runMissingFingerDetection()
    fprintf('\n--- Missing Finger Detection ---\n');
    img = selectImage();
    if ~isempty(img)
        fprintf('Running missing finger detection...\n');
        RubberFinger(img);
        fprintf('Results displayed and saved to RNpic.mat and RNvariables.mat\n\n');
    end
end

function runAllDetectors()
    fprintf('\n--- Running All Detectors ---\n');
    img = selectImage();
    if ~isempty(img)
        fprintf('Running hole detection...\n');
        RubberHole(img);
        
        fprintf('Running stain detection...\n');
        RubberStain(img);
        
        fprintf('Running missing finger detection...\n');
        RubberFinger(img);
        
        fprintf('All detections complete. Results displayed and saved to RNpic.mat and RNvariables.mat\n\n');
    end
end

function img = selectImage()
    % Helper function to select and load an image
    [fname, pname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif', 'Image Files (*.jpg,*.png,*.bmp,*.tif)'; '*.*', 'All Files'}, ...
                                'Select a Rubber Nitrile Glove Image');
    
    if isequal(fname, 0)
        fprintf('Image selection cancelled.\n\n');
        img = [];
    else
        img = imread(fullfile(pname, fname));
        fprintf('Loaded image: %s\n', fname);
    end
end
