function [ mask_array, mask_angles, mask_image ] = phal_read_maskfile( mask_filename, mask_pathname, scale_factor )
% READ_MASKFILE
% This function translates a 2D array or image to a 3D array with separate masks
% inputs: 
% - a file name and path
% - a scale factor it should be scaled to larger sizes more squares (e.g. 3 for 9 squares)
% IMPORTANT for input .mat files: need to contain an array named 'mask'
% output:   a 3D matrix with a series of masks
%           a vector with all the angles
%           a 2D matrix containing the whole image in gray scale for imshow

if ~exist('scale_factor', 'var')
    scale_factor = 1;
end
correction = 0;


if endsWith(mask_filename, {'.jpg','.jpeg','.png','.bmp'},'IgnoreCase',true)
    % if using an image 
    
    % ask for how many masks to use
    disp('choosing an image file')
        % using newid instead of inputdlg because it defaults to enter!
    userinput = str2double(newid('Number of Masks','Please input',1,{'2'})); 
    if isnan(userinput)
        % no mask number given
        disp('no numeric value given, using two masks')
        nof_masks = 2;
    elseif round(userinput) == 1
        % single is difficult
        nof_masks = 2;
        disp('changing to two masks, for programming reasons')
    elseif isempty(userinput)
        % if someone presses cancel, userinput is empty
        disp('no numeric value given, using two masks')
        nof_masks = 2;
    else
        % if it is a reasonable value
        disp(['using ', num2str(round(userinput)), ' masks'])
        nof_masks = round(userinput);
    end
    
    % read image file
    disp(['loading image ', strcat(mask_pathname,mask_filename)]);
    img_file = imread(strcat(mask_pathname,mask_filename));
    % combine red green and blue channel to one channel
    mask = sum(img_file, 3);
    
    % scale it before discreetizing
    aspect_ratio = size(mask, 2)/size(mask, 1);
    disp(['Original ratio: ', num2str(round(aspect_ratio, 2)), ', scaling to 1:1'])
    mask = imresize(mask, scale_factor*[768, 768], 'bilinear');
    
    % normalize it
    mask = mask/max(max(mask)); 
    
    % discretize it
    for n = 1:nof_masks
        mask((mask <= n/nof_masks) & (mask > (n-1)/nof_masks)) = (n-1)/(nof_masks-1);
    end
    % rescale it to 90 degree (can also set it to 180 degree)
    mask = mask*(90/nof_masks*(nof_masks-1));
    mask_angles = unique(mask);
    
elseif endsWith(mask_filename, '.mat', 'IgnoreCase', true)
    % if using a .mat file
    temp = load(strcat(mask_pathname,mask_filename));

    try
        % the mask file should just contain one array named array
        mask = temp.mask;
    catch
        disp('not a valid mask file, no array named "mask"')
        mask_array = zeros(768*scale_factor, 768*scale_factor, 2);
        mask_array(:,:,2) = 1;
        mask_angles = [0,90];
        mask_image = zeros(768*scale_factor, 768*scale_factor);
        return
    end
    mask(isnan(mask)) = 0;
        
    % count how many different angle values we have
    mask_angles = unique(mask);
    nof_masks = length(mask_angles);
    disp(['Found ', num2str(nof_masks),' angles.']);
    
    if nof_masks == 1
        disp('changing to two masks, for programming reasons')
        nof_masks = 2;
        correction = 1;
        mask_angles = [mask_angles, mask_angles];
    end
    aspect_ratio = size(mask, 2)/size(mask, 1);
    disp(['Original ratio: ', num2str(round(aspect_ratio, 2)), ', scaling to 1:1'])
    % scale it to fit for more squares
    % nearest fit to keep it discreet
    mask = imresize(mask, scale_factor*[768, 768], 'nearest');
end

% normalize it
mask_image = mask/max(max(mask));

% create one mask for each angle
mask_array = zeros(size(mask,1),size(mask,2),nof_masks);
for n = 1:nof_masks
    temp_mask = mask;
    if mask_angles(n) ~= 0
        temp_mask(temp_mask ~= mask_angles(n)) = 0;
        temp_mask(temp_mask == mask_angles(n)) = 1;
    else
        temp_mask(temp_mask ~= mask_angles(n)) = 1;
        temp_mask = imcomplement(temp_mask);
    end
    mask_array(:,:,n) = temp_mask;
    % for debugging show the single masks
    %     figure()
    %     imshow(temp_mask)
    %     pause(0.5)
    %     close()
end

if correction
    mask_array(:, :, 2) = 0;
end
clear temp_mask

end

