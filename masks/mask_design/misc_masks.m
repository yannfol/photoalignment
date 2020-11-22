% Design of masks

%% blank mask
mask = zeros(768, 768);
save('../blankmask','mask');

%% generate number masks 0-9
zerotonine = imread('0123456789.jpg');
zerotoninestretched = imresize(zerotonine, 10, 'nearest');
zerotonine1d = zerotoninestretched(:, :, 1);
zerotonine1d(zerotonine1d < 10) = 0;
zerotonine1d(zerotonine1d > 200) = 255;
save('../zerotonine.mat', 'zerotonine1d')
imagesc(~zerotonine1d)

%% generate number masks 1-0
onetozero = imread('1234567890.jpg');
onetozerostretched = imresize(onetozero, 10, 'nearest');
onetozero1d = onetozerostretched(:, :, 1);
onetozero1d(onetozero1d < 10) = 0;
onetozero1d(onetozero1d > 200) = 255;
save('../onetozero.mat', 'onetozero1d')
imagesc(~onetozero1d)

%% generate number masks 0-F
zerotoF = imread('0123456789ABCDEF.jpg');
zerotoFstretched = imresize(zerotoF, 10, 'nearest');
zerotoF1d = zerotoFstretched(:, :, 1);
zerotoF1d(zerotoF1d < 10) = 0;
zerotoF1d(zerotoF1d > 200) = 255;
save('../zerotoF.mat', 'zerotoF1d')
imagesc(~zerotoF1d)

%% random mask
nof_pixels = 768/4;
mask = rand(nof_pixels);
mask(mask<0.5)=0;
mask(mask>=0.5)=1;
imshow(mask)
save(['../fun_masks/random_',num2str(nof_pixels),'.mat'],'mask');
clear mask

