%% radial mask

% number of exposure steps
nof_steps = 12;
% number of pixel
nof_pix = 3*768;

% change colormaps
ycolormap('balance');
ycolor('moreland');

% generate the upper side of the image
mask = zeros(nof_pix, nof_pix);
for n=1:size(mask, 1)/2
    for m=1:size(mask, 2)
        mask(n, m) = atan2d((-(n-nof_pix/2)), (m-nof_pix/2)); 
        % minus in front of n because imagesc/imagesc invert y axis
    end
end
% make the negative part positive
mask(mask < 0) = mask(mask < 0) + 360;
mask(nof_pix/2+1:end, :) = rot90(mask(1:nof_pix/2,:),2);

% just in case we divided by 0 somewhere
mask(isnan(mask)) = 0;
max(max(mask))

figure(1)
    imagesc(mask)
    axis off
    axis square
    colorbar

%% make discreet
% first make two times as many steps as necessary
[N, edges] = histcounts(mask, 'BinWidth', 180/(2*nof_steps));
% [N, edges] = histcounts(mask, 'BinWidth', 180/(1*nof_steps));
for n = 1:length(N)
    mask(mask >= edges(n) & mask < edges(n+1)) = edges(n);
end
% move 180 to 0
mask(mask==180) = 0;

% then combine always two steps
for n = 1:length(N)
    if n == length(N)
        % make the first and the last one zero
        mask(mask >= edges(n)) = edges(1);
    elseif mod(n, 2) == 0
        mask(mask >= edges(n) & mask < edges(n+2)) = edges(n+1);
    end
end

% rotate the upper half 180 degree to get the bottom side
mask(nof_pix/2+1:end, :) = rot90(mask(1:nof_pix/2,:),2);

% move 180 to 0
mask(mask==180) = 0;

figure(2)
    imagesc(mask)
    axis square
    axis off
    colorbar

    
    
%% quiver it
% maskquiv = imresize(mask, 0.02, 'nearest');
% nof_pix_quiv = size(maskquiv, 1);
% x = 1:size(maskquiv,2);
% y = 1:size(maskquiv,1);
% [X, Y] = meshgrid(x, y);
% U = cosd(maskquiv);
% V = -sind(maskquiv);    
% 
% colorindex2 = 4;
% figure(3)
%     imagesc(maskquiv)
%     axis square
%     axis off
%     colorbar
%     hold on
%     quiver(X, Y, 0.5*U, 0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1.4,...
%            'Autoscale', 'on', 'autoscalefactor', 0.405,'color','black')
%     quiver(X, Y, -0.5*U, -0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1.4,...
%            'Autoscale', 'on', 'autoscalefactor', 0.405,'color','black')
%     set(gca,'ColorOrderIndex',colorindex2)
%     quiver(X, Y, 0.5*U, 0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1,...
%            'Autoscale', 'on', 'autoscalefactor', 0.4)
%     set(gca,'ColorOrderIndex',colorindex2)
%     quiver(X, Y, -0.5*U, -0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1,...
%            'Autoscale', 'on', 'autoscalefactor', 0.4)
%     hold off
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
savename = ['../radial_masks/radial_', nof_pix_str, 'px_', nof_steps_str, 'steps.mat']
save(savename, 'mask')
close all
