%% 1D Pancharatnam-Berry-Deflector (fixed period, fixed step number)
nof_pix = 3*768;
period = 16; % period in pixel, one pixel being ~6.5 μm
nof_steps = 4;

mask = zeros(nof_pix, nof_pix);

for n=1:size(mask, 1)
    mask(:,n) = mod(n, round(period))*180/period;
end

% discretize if we want less steps than our period has pixels
if nof_steps < period
    [~, edges] = histcounts(mask, nof_steps);
    delta_edges = edges(2)-edges(1);
    mean_edges = zeros(length(edges)-1, 1);
    for n=1:length(edges)-1
        mean_edges(n) = (edges(n) + edges(n+1))/2;
    end
    for n=1:nof_steps
        [row, col] = find(mask >= edges(n) & mask < edges(n)+delta_edges);
        for m=1:length(row)
            mask(row(m), col(m)) = mean_edges(n);
        end
    end
elseif nof_steps >= period
    disp('using just as many steps as the period has')
end
    
figure(1)
    plot(mask(1,:))

figure(2)
    imagesc(mask)
    axis off
    colorbar
    
savename = ['../PBdeflectors/PBD_fixed_', num2str(nof_pix), 'px_', num2str(period), 'period_', num2str(nof_steps), 'steps.mat'];    
save(savename, 'mask'); pause(2); close all;

%% 1D Pancharatnam-Berry Deflector with varying period, fixed step number
nof_pix = 4*768;
period_start = 16; % period in pixel, one pixel being ~6.5 μm
period_end = 64;
nof_steps = 8;

mask = zeros(nof_pix, nof_pix);
modvalue = zeros(size(mask, 1), 1);
for n=1:size(mask, 1)
    % linear scale of the modulus value:
    modvalue(n) = n/nof_pix * (period_end-period_start) + period_start;
    % careful: need to round modvalue, else it will give a different period!
    mask(:,n) = mod(n, round(modvalue(n)))*180/modvalue(n);
end

figure(1)
    plot(mask(1,:))
    
% discretize
[~, edges] = histcounts(mask, nof_steps);
delta_edges = edges(2)-edges(1);
mean_edges = zeros(length(edges)-1, 1);
for n=1:length(edges)-1
    mean_edges(n) = (edges(n) + edges(n+1))/2;
end
for n=1:nof_steps
    [row, col] = find(mask >= edges(n) & mask < edges(n)+delta_edges);
    for m=1:length(row)
        mask(row(m), col(m)) = mean_edges(n);
    end
end
% set the lowest value to zero
mask = mask-min(min(mask));

figure(1)
    hold on
    plot(mask(1,:),'+')
    hold off
    
figure(3)
    imagesc(mask)
    axis off
    colorbar

savename = ['../PBdeflectors/PBD_', num2str(nof_pix), 'px_', num2str(period_start), '-', num2str(period_end), 'period_', num2str(nof_steps), 'steps.mat'];    
save(savename, 'mask'); pause(3); close all;
