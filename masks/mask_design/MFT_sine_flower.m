%% MTF sine flower
% from https://commons.wikimedia.org/wiki/File:MTF_sine_flower.png
nof_pix = 3*768;
nof_spikes = 16;

mask = zeros(nof_pix, nof_pix);
% give every point just its angle from the origin
for n=1:size(mask, 1)
    for m=1:size(mask, 2)
        mask(n, m) = atan2d((m-nof_pix/2), (n-nof_pix/2));
    end
end
% take the sine of the angles scaled with number of spikes
mask = sind(nof_spikes*mask);

% scale to [-1, 1] to [0, 1]
mask = (mask + 1)/2;

% this gives a smooth MTF flower
figure(1)
    imagesc(mask)
    axis off
    colorbar
    
% discretize    
mask(mask <= 0.5) = 0;
mask(mask > 0.5) = 1;
figure(2)
    imagesc(mask)
    axis off
    colorbar
    
% close all
savename = ['../sine_flower_', num2str(nof_pix), 'px_', num2str(nof_spikes), 'spikes.mat'];
% save(savename, 'mask')
