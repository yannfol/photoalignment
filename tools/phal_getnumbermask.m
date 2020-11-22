function squarenumbermask = phal_getnumbermask();

squarenumbermask = zeros(60, 60, 10);

% load mat file with the pixel distribution of the numbers
% 60 rows, 50 columns per number
% temp = load('zerotonine.mat'); % for numbers 0 to 9
load('onetozero.mat'); % for numbers 1 to 0
% temp = load('zerotoF.mat'); % for numbers 0 to F

% invert it
onetozero = ~onetozero1d;


% disp('generating number masks')
% put them in a 3D array, a 60x60 image per number
for n = 1:size(squarenumbermask,3)
    squarenumbermask(:, 1:50, n) = onetozero(:, ((n-1)*50+1):(n*50));
%     figure(1)
%     imshow(squarenumbermask(:, 1:50, n));
%     pause(2)
end


end
