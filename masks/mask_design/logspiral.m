%% create a logarithmic spiral
% by Yannick Folwill (yannick.folwill@posteo.eu)

% number of exposure steps
nof_steps = [9, 18, 36];
% number of pixels
nof_pix = 4*768;

mask = zeros(nof_pix, nof_pix);
x = linspace(-1, 1, nof_pix);
y = x;

% change colormaps
ycolormap('balance');

% select opening angle for function r = exp(b(theta-phi))
opening_angle_deg = 50;
opening_angle = deg2rad(opening_angle_deg);
b = cos(opening_angle)/sin(opening_angle);


for n=1:size(mask,1)
    for m=1:size(mask,2)
        % offset angle
        theta_i = atan2(y(m), x(n));
        % logspiral angle
        mask(m, n) = 1/b * log(cos(theta_i)/x(n)) + theta_i;
        if isnan(mask(m, n))
            mask(m, n) = mask(m-1, n);
        elseif ~isreal(mask(m, n))
            mask(m, n) = 0;
        end
    end
end
mask = rem(mask, pi);
mask(mask<0) = mask(mask<0) + pi;

figure(1)
imagesc(mask)
    axis square
    axis off
    colorbar()

mask_cont = mask;    

%% discretize for every nof_steps given and export
for o=1:length(nof_steps)
    [N, edges] = histcounts(mask_cont, nof_steps(o));
    edgediff = edges(2) - edges(1);
    for n = 1:length(N)
        mask(mask_cont >= edges(n) & mask_cont < edges(n+1)) = edges(n);
    end
    % rescale to 180 degree
    mask = mask/max(max(mask))*(180-180/nof_steps(o));
%     unique(mask)

    figure(2)
        imagesc(mask)
        axis square
        axis off
        colorbar

    %% create quiver plot
    maskquiv = imresize(mask, 0.02, 'nearest');
    nof_pix_quiv = size(maskquiv, 1);
    x = 1:size(maskquiv,2);
    y = 1:size(maskquiv,1);
    [X, Y] = meshgrid(x, y);
    U = cosd(maskquiv);
    V = -sind(maskquiv);

    colorindex = 8;
    colorindex2 = 4;
    figure(6)
        imagesc(maskquiv)
        hold on
        set(gca,'ColorOrderIndex',colorindex)
            quiver(X, Y, 0.5*U, 0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1.4,...
               'Autoscale', 'on', 'autoscalefactor', 0.405,'color','black')
        set(gca,'ColorOrderIndex',colorindex)
        quiver(X, Y, -0.5*U, -0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1.4,...
               'Autoscale', 'on', 'autoscalefactor', 0.405,'color','black')
        set(gca,'ColorOrderIndex',colorindex2)
        quiver(X, Y, 0.5*U, 0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1,...
               'Autoscale', 'on', 'autoscalefactor', 0.4)
        set(gca,'ColorOrderIndex',colorindex2)
        quiver(X, Y, -0.5*U, -0.5*V, 'ShowArrowHead', 'off', 'linewidth', 1,...
               'Autoscale', 'on', 'autoscalefactor', 0.4)
        hold off
        axis square
        axis off
        colorbar

    %% save mask    
    savename = ['../logspirals/logspiral_', num2str(opening_angle_deg), 'deg_', num2str(nof_pix), 'px_', num2str(nof_steps(o)), 'steps.mat']
    save(savename, 'mask'); disp(['saved as', savename]);
    close all
end