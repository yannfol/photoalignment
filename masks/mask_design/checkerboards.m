%% checkerboards
% number of pixels
nof_pix = 4*768;
% pixels per angle
pix_per_angle = 80;
% number of angle steps
nof_steps = 2;

% change colormaps
ycolormap('balance');

ax = zeros(nof_pix, nof_pix);
ay = zeros(nof_pix, nof_pix);
idx = 0;

for n = 1:size(ay, 1)
    if n ~= 1
        if mod(n, pix_per_angle) == 0
            if idx < (nof_steps-1)
                idx = idx + 1;
            else
                idx = 0;
            end
        end
    end
    ay(n, :) = idx;
    ax(:, n) = idx;
end
mask = ax + ay;
mask(mask>=nof_steps) = mask(mask>=nof_steps) - nof_steps;


figure(1)
    imagesc(mask)
    axis off
    axis square
    colorbar

    
%%
if nof_pix > 999
    nof_pix_str = num2str(nof_pix);
else
    nof_pix_str = ['0', num2str(nof_pix)];
end
if nof_steps > 9
    nof_steps_str = num2str(nof_steps);
else 
    nof_steps_str = ['0', num2str(nof_steps)];
end
if pix_per_angle > 99
    ppa_str = num2str(pix_per_angle);
else 
    ppa_str = ['0', num2str(pix_per_angle)];
end
savename = ['../chckrbrd_', nof_pix_str, 'px_', ppa_str, 'ppa_', nof_steps_str, 'steps.mat']
save(savename, 'mask')
close all
