input_img = imread(".\Latex Glove\Contamination.jpeg");

hsv_result = rgb2hsv(input_img);
H = hsv_result(:,:,1);
S = hsv_result(:,:,2);
V = hsv_result(:,:,3);

hue = (H < 0.5 | H > 0.95);
sat = S > 0.45;
val = (V > 0.20) & (V < 0.95);

final = hue & sat & val;

figure;
subplot(2,3,1)
imshow(input_img);
title("Orginal");

subplot(2,3,2);
imshow(H, []);
title("Hue");

subplot(2,3,3)
imshow(S,[]);
title("Saturation");

subplot(2,3,4)
imshow(V,[]);
title("Value");

subplot(2,3,5);
imshow(final);
title("Threshold")

subplot(2,3,6)
imshow(labeloverlay(input_img, final, "Transparency",0.4));
title("Overlay Mask")

% this is good to mask the glove and see if it can separate objects and
% glove indefinitely. Now the next idea is to find a filter that detects it 