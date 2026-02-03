
function MainMenu()
	clc;
	fprintf('\nRubber Glove Defect Detection - Main Menu\n');

	while true
		fprintf('\n1) Holes Detector\n');
		fprintf('2) Missing Finger Detector\n');
		fprintf('3) Stain Detector\n');
		fprintf('4) Process Folder of Images\n');
		fprintf('5) Exit\n');

		choice = input('Select an option (1-5): ', 's');

		switch choice
			case '1'
				runHolesDetector();
			case '2'
				runMissingFingerDetector();
			case '3'
				runStainDetector();
			case '4'
				processFolder();
			case '5'
				fprintf('Exiting.\n');
				return;
			otherwise
				fprintf('Invalid choice.\n');
		end
	end
end

function runHolesDetector()
	try
		fprintf('\n-- Holes Detector --\n');
		[file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.jpeg','Image Files'}, 'Select image for Holes Detector');
		if isequal(file,0), fprintf('No file selected.\n'); return; end
		fullpath = fullfile(path,file);
		img = imread(fullpath);
		RubberHole(img);
		displayResults(fullpath, 'Holes');
	catch ME
		fprintf('Error: %s\n', ME.message);
	end
end

function runMissingFingerDetector()
	try
		fprintf('\n-- Missing Finger Detector --\n');
		[file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.jpeg','Image Files'}, 'Select image for Missing Finger Detector');
		if isequal(file,0), fprintf('No file selected.\n'); return; end
		fullpath = fullfile(path,file);
		img = imread(fullpath);
		RubberNitrileMissingFingerDetector(img);
		displayResults(fullpath, 'MissingFinger');
	catch ME
		fprintf('Error: %s\n', ME.message);
	end
end

function runStainDetector()
	try
		fprintf('\n-- Stain Detector --\n');
		[file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.jpeg','Image Files'}, 'Select image for Stain Detector');
		if isequal(file,0), fprintf('No file selected.\n'); return; end
		fullpath = fullfile(path,file);
		img = imread(fullpath);
		RubberNitrileStainDetector(img);
		displayResults(fullpath, 'Stain');
	catch ME
		fprintf('Error: %s\n', ME.message);
	end
end

function processFolder()
	try
		folder = uigetdir(pwd, 'Select folder of images to process');
		if isequal(folder,0), fprintf('No folder selected.\n'); return; end
		files = dir(fullfile(folder, '*.jpg'));
		files = [files; dir(fullfile(folder, '*.png')); dir(fullfile(folder, '*.bmp')); dir(fullfile(folder, '*.jpeg'))];
		if isempty(files), fprintf('No images found in folder.\n'); return; end
		for k = 1:length(files)
			fname = fullfile(folder, files(k).name);
			img = imread(fname);
			% Run holes detector by default for batch processing
			RubberHole(img);
			fprintf('Processed: %s\n', files(k).name);
		end
		fprintf('Folder processing complete.\n');
	catch ME
		fprintf('Error: %s\n', ME.message);
	end
end

function displayResults(filename, dtype)
	try
		% Load original image using the provided path
		if exist(filename, 'file')
			original = imread(filename);
		else
			fprintf('Original image not found: %s\n', filename);
			return;
		end

		if exist('RNpic.mat', 'file')
			S = load('RNpic.mat');
		else
			S = struct();
		end
		if exist('RNvariables.mat', 'file')
			V = load('RNvariables.mat');
		else
			V = struct();
		end

		figure('Name', ['Result: ' dtype], 'NumberTitle', 'off');
		subplot(1,2,1); imshow(original); title('Original');
		subplot(1,2,2); imshow(original); title('Detections'); hold on;

		switch dtype
			case 'Holes'
				if isfield(V, 'large_holes') && ~isempty(V.large_holes)
					for i=1:length(V.large_holes)
						rectangle('Position', V.large_holes(i).BoundingBox, 'EdgeColor','r','LineWidth',2);
					end
				else
					text(10,20,'No holes detected','Color','y','FontSize',12);
				end
			case 'MissingFinger'
				if isfield(V, 'LMissingFinger') && ~isempty(V.LMissingFinger)
					for i=1:length(V.LMissingFinger)
						rectangle('Position', V.LMissingFinger(i).BoundingBox, 'EdgeColor','r','LineWidth',2);
					end
				else
					text(10,20,'No missing fingers detected','Color','y','FontSize',12);
				end
			case 'Stain'
				if isfield(V, 'LRNStain') && ~isempty(V.LRNStain)
					for i=1:length(V.LRNStain)
						rectangle('Position', V.LRNStain(i).BoundingBox, 'EdgeColor','r','LineWidth',2);
					end
				else
					text(10,20,'No stains detected','Color','y','FontSize',12);
				end
		end

		hold off;
	catch ME
		fprintf('Display error: %s\n', ME.message);
	end
end
