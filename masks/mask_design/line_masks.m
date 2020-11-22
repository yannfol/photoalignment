%% line mask 20 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 20
        mask(:,i) = 1;
        m = m +1;
    elseif m == 40
        m = 1;
    else
        m = m+1;
    end
end
% save('LineGrating_20px_ver','mask');
imagesc(mask)

%% line mask 10 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 10
        mask(:,i) = 1;
        m = m +1;
    elseif m == 20
        m = 1;
    else
        m = m+1;
    end
end
% save('LineGrating_10px_ver','mask');
imagesc(mask)

%% line mask 5 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 5
        mask(:,i) = 1;
        m = m +1;
    elseif m == 10
        m = 1;
    else
        m = m+1;
    end
end
% save('LineGrating_5px_ver','mask');
% imagesc(mask)

%% line mask 2 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 2
        mask(:,i) = 1;
        m = m +1;
    elseif m == 4
        m = 1;
    else
        m = m+1;
    end
end
% save('LineGrating_2px_ver','mask');
% imagesc(mask)

%% line mask 1 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 1
        mask(:,i) = 1;
        m = m +1;
    elseif m == 2
        m = 1;
    else
        m = m+1;
    end
end
% save('LineGrating_1px_ver','mask');
% imagesc(mask)

%% bar mask
mask = zeros(768,768);
mask(1:256,:) = 1;
mask(513:end,:) = 1;
% imagesc(mask)
% save('bar_mask_horizontal', 'mask');

mask = zeros(768,768);
mask(:,1:256) = 1;
mask(:,513:end) = 1;
% imagesc(mask)
% save('bar_mask_vertical', 'mask');

%% half mask
mask = zeros(768,768);
mask(1:384,:) = 1;
% imagesc(mask)
% save('half_mask_horizontal', 'mask');
mask = zeros(768,768);
mask(:, 1:384) = 1;
% imagesc(mask)
% save('half_mask_vertical', 'mask');

%% four step line mask 20px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 20
        mask(:,i) = 1;
        m = m +1;
    elseif (m <= 40) && (m > 20)
        mask(:,i) = 2;
        m = m +1;
    elseif (m <= 60) && (m > 40)
        mask(:,i) = 3;
        m = m + 1;
    elseif m == 80
        m = 1;
    else
        m = m+1;
    end
end
mask = mask/3;
save('../LineGrating_4step_20px_ver','mask');
% imagesc(mask)

%% four step line mask 10 px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 10
        mask(:,i) = 1;
        m = m +1;
    elseif (m <= 20) && (m > 10)
        mask(:,i) = 2;
        m = m +1;
    elseif (m <= 30) && (m > 20)
        mask(:,i) = 3;
        m = m + 1;
    elseif m == 40
        m = 1;
    else
        m = m+1;
    end
end
mask = mask/3;
save('../LineGrating_4step_10px_ver','mask');
% imagesc(mask)

%% four step line mask 5px
mask = zeros(768,768);
m = 1;
for i = 1:size(mask,2)
    if m <= 5
        mask(:,i) = 1;
        m = m +1;
    elseif (m <= 10) && (m > 5)
        mask(:,i) = 2;
        m = m +1;
    elseif (m <= 15) && (m > 10)
        mask(:,i) = 3;
        m = m + 1;
    elseif m == 20
        m = 1;
    else
        m = m+1;
    end
end
mask = mask/3;
save('../LineGrating_4step_5px_ver','mask');
% plot(mask(300, :))
% imagesc(mask)

%% other line gratings
clear
name = 'LineGrating_1to6px_centered';
s = 768;        % Enter size of the mask to make
m = zeros(s,s); % Create an array of size
t = zeros(s,s);

z = 3;          % Horizontal Zones
ed = 5;         % Pixels on edge
h = (s-2*ed)/z; % height of each line
k = 4;          % No of lines per resolution
r = 13;         % Max Resolution
vec = zeros(r,1);

clear i

for j=1:r
    vec(j)= ed + 4.5*(j-1)*j;
    m(:,vec(j):j-1+vec(j))=1;
    y = vec(j);
    for i=[1 2 3]
        m(:,y+i*2*j-1:y+(i+1)*2*j-1) = m(:,y-j:y+j);
    end
end

m = m(:,1:s);

t(:,1+s/2:s) = m(:,1:s/2);
t = t + flip(t,2);

%t = m + m';
% mask = struct;
% imagesc(t);
% imagesc(m);

mask = m;
save('LineGrating_1to13px_hor','mask');         % Export the mask mat file
clear mask
mask = m';
save('LineGrating_1to13px_ver','mask');         % Export the mask mat file
clear mask

mask = t;
save('LineGrating_1to6px_centered_hor','mask');
clear mask

mask = t';
save('LineGrating_1to6px_centered_ver','mask');
clear mask

%% multistep line mask (gradient line)
nof_pix = [768, 3*768, 4*768];
nof_steps = [6, 8, 10, 18, 36];
pix_per_step = [5, 10, 20];

for p = 1:length(nof_pix)
    for o = 1:length(nof_steps)
        for m = 1:length(pix_per_step)
            mask = zeros(nof_pix(p), nof_pix(p));
            edges = 0:(180/nof_steps(o)):180;

            counter = 1;
            for n = 1:pix_per_step(m):size(mask, 2)
                mask(:, n:(n+pix_per_step(m)-1)) = edges(counter);
                counter = counter +1;
                if counter == length(edges)
                    counter = 1;
                end
            end

            figure(1)
                imagesc(mask)
                axis off
                axis square
                colorbar

            if nof_pix(p) > 999
                nof_pix_str = num2str(nof_pix(p));
            else
                nof_pix_str = ['0', num2str(nof_pix(p))];
            end
            if nof_steps(o) > 9
                nof_steps_str = num2str(nof_steps(o));
            else 
                nof_steps_str = ['0', num2str(nof_steps(o))];
            end
            if pix_per_step(m) > 9
                pix_per_step_str = num2str(pix_per_step(m));
            else 
                pix_per_step_str = ['0', num2str(pix_per_step(m))];
            end
            savename = ['../x-gradients/gline_', nof_pix_str, 'px_', nof_steps_str, 'steps_', pix_per_step_str, 'pps.mat']
%             save(savename, 'mask')
            pause(1)
            close all
        end
    end
end