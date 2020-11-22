%%----------------------------------------------------------------------------------
% This is a MATLAB GUI made for Photoalignment of Liquid Crystals using
% - a projector with a DMD (as second screen)
% - a rotation-controlled Polarizer (Standa rotation stage)
% - a mask file for supplying the individual orientations for each pixel
%%----------------------------------------------------------------------------------
% Faced with the choice of changing one’s mind and proving that there is no need to
% do so, almost everyone gets busy on the proof.
% -- John Kenneth Galbraith
%%----------------------------------------------------------------------------------


function varargout = phal(varargin)

% Last Modified by GUIDE v2.5 26-May-2020 17:52:39

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @phal_OpeningFcn, ...
                   'gui_OutputFcn',  @phal_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before phal is made visible.
function phal_OpeningFcn(hObject, ~, h, varargin)
% set format
%     clc;
    format compact
    % cd to the phal.m-directory
    cd(fileparts(mfilename('fullpath')));
    % change the version number here on major updates
    h.phal_version = 2.0;


% disable serial read warnings
    warning('off','MATLAB:serial:fscanf:unsuccessfulRead')

% set gui position
    h.figure_phal.Units = 'pixels';
    h.figure_phal.Position = [1, 100, 1383, 787];

% path
    % for the stage functions
    addpath('standa')
    % for the masks
    addpath('masks')
    % for colors, sendmail
    addpath('tools')

% email addresses for debug messages, sender account needs to be set in tools/phal_sendmail
    h.recipient1_name = 'Guenther';
    h.recipient1_email = 'guenther@somewhere.com';
    h.run_checkbox_notification.String = ['notification to ',  num2str(h.recipient1_name)];
    h.recipient2_name = 'Horst';
    h.recipient2_email = 'horst@somewhere.com';
    h.run_checkbox_notification2.String = ['notification to ',  num2str(h.recipient2_name)];

% projected image size
    h.imgwidth = 4.9; % width of the projected image on the substrate in mm (square)
    h.masks_edit_img_width.String = num2str(h.imgwidth);

% preset exposure time
    h.preset_exp_time = 10;

% stage offsets
    % offset of the start position (negative of what you need for the stage
    % to be at (0,0)
    % previous: (2,2)
    h.stage_offset_x = 3.2; % modified 2020-07-30
    h.stage_offset_y = 1.5; % modified 2020-08-11 after zeroing the stage
    % angle at which pol is parallel to x-axis
    h.stage_offset_rot = 0; %-10.9; % modified 2020-09-03 after mounting new polarizer

% fontsize and markersize
    h.fontsize = [10, 8, 6];
    h.markersize = [15.5, 6.7, 4]*h.imgwidth;

% colors
    h.color = load_colors(hObject, h);
    h.dark_mode = 1;
    h.gui_checkbox_darkmode.Value = 1;
    toggle_dark_mode(hObject, h);

% get id for rotation, x and y stage
    try
        [h.device_id_rot, h.device_id_x, h.device_id_y, ~] = standa_open();
    catch
        h.device_id_rot = 9;
        h.device_id_x = 9;
        h.device_id_y = 9;
    end
    pause(0.5)

% substrate setup
    preset_substrate_value = 5;
    h.xy_popupmenu_subsdiam.Value = preset_substrate_value;
    h.samplenames = {'s01', 's02', 's03', 's04', 's05', 's06', 's07'};
    h = configure_xy_plot(hObject, h, preset_substrate_value, 1);

% Show the current stage positions
    h = show_rot_position(hObject,h);
    h = show_xy_position(hObject, h);

% stage speed
    h.rot_speed = 5; % estimated rotation speed in deg/s
    h.xy_speed = 5; % estimated xy speed in in mm/s

% reset parameters
    h.blackmask = zeros(768,768);
    h.whitemask = ones(768,768);
    h.pause_exposure = 0;
    h.notification_enabled = 0;
    h.notification2_enabled = 0;
% humidity
    h.humidity_enabled = 0;
    h.humidity_target = 32;
    h.hum_edit_target.String = num2str(h.humidity_target);
    h.hum_checkbox_control.Visible = 'off';
    global humidity_log
    humidity_log = zeros(1e6,1);
    global humidity_index
    humidity_index = 1;
% post exposure humidification according to Wang2016, 80-90%, 18h
    h.pexphum_enabled = 0;
    h.pexphum_humidity = 80; % RH% (or as much as possible)
    h.pexphum_time = 60*20; % in seconds

% label
    label_phal = imread('label_phal.png');
    image(label_phal,'Parent',h.gui_axes_label);

% set parameters for connection to arduino sensor
    if isunix
        % if on linux use this port
        h.serialport_arduino = '/dev/ttyUSB5';
    else
        % if on windows use this port
        h.serialport_arduino = 'COM21';
    end
    h.hum_edit_port.String = h.serialport_arduino;

% close and delete all available devices
    comdevices = instrfind;
    if ~isempty(comdevices)
        fclose(comdevices);
        delete(comdevices);
    end
    clear comdevices

% set which screen the projector is
    if isunix
        % on linux it is currently set up as screen 2
        h.screen_no = 2;
    else
        % on windows it is set up as screen 2
        h.screen_no = 2;
    end

% preset current and voltage for LED
    h.preset_current = 0.95;
    h.preset_voltage = 3.7;
    h.multicurrent_index = 0;

% find LED serial port object.
    if isunix
        h.serialport_led = '/dev/ttyUSB4';
    else
        h.serialport_led = 'COM20';
    end
    serial_led = instrfind('Type', 'serial', 'Port', h.serialport_led);
    if ~isempty(serial_led)
        fclose(serial_led);
    end
    h.led_enable = 0;
    h.run_popup_presets.Value = 1; % set it to low current for being safe

% disable the exposure buttons
    disable_exp_buttons(hObject, h);

% import number pixel masks for numbers 1 to 0
    h.squarenumbermask = phal_getnumbermask;

% Choose default command line output for phal
    h.output = hObject;

% Update h structure
guidata(hObject, h);

% --- Outputs from this function are returned to the command line.
function varargout = phal_OutputFcn(~, ~, h)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure_phal
% eventdata  reserved - to be defined in a future version of MATLAB
% h    structure with handles and user data (see GUIDATA)

% Get default command line output from h structure
varargout{1} = h.output;

%%----------------------------------------------------------------------------------
%%----------------------------------------------------------------------------------
                            % CREATE FUNCTIONS
%%----------------------------------------------------------------------------------
%%----------------------------------------------------------------------------------

% graphs
function masks_axes_square_CreateFcn(hObject, ~, ~)
axes(hObject);
axis off;

function masks_axes_currmask_CreateFcn(hObject, ~, ~)
axes(hObject);
axis off;

function masks_axes_cluster_CreateFcn(hObject, ~, ~)
axes(hObject);
axis off;

function rot_axes_currpos_CreateFcn(hObject, ~, ~)
axes(hObject);
axis off;

% edit fields
function rot_edit_set_angle_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function xy_edit_x_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function xy_edit_y_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function xy_edit_movetosquare_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function masks_listbox_square_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function masks_listbox_cluster_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function xy_popupmenu_subsdiam_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function run_popup_presets_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function hum_edit_target_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function hum_edit_port_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function masks_edit_img_width_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%----------------------------------------------------------------------------------
%%----------------------------------------------------------------------------------
                                % CALLBACKs
%%----------------------------------------------------------------------------------
%%----------------------------------------------------------------------------------

%%----------------------------------------------------------------------------------
% mask panel (masks)
%%----------------------------------------------------------------------------------
function masks_edit_img_width_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        h.masks_edit_img_width.String = num2str(h.imgwidth);
        return
    elseif ~(abs(round(input)) <= 100)
        disp('invalid image size, maximum is 100')
        h.masks_edit_img_width.String = num2str(h.imgwidth);
    else
        h.imgwidth = abs(input);
        disp(['changed image width to ', num2str(input), ' mm'])
        h = configure_xy_plot(hObject, h, h.xy_popupmenu_subsdiam.Value, 0);
        h = redraw_xy_plot(hObject, h);
    end
    guidata(hObject, h)

function masks_listbox_square_Callback(hObject, ~, h)
    chosen_x_index = get(hObject,'Value');
    h.chosen_square = chosen_x_index;
%     disp(strjoin(['chosen square:', strjoin(string(h.chosen_square))]));

    % delete plots
    clear_plot(hObject, h, h.masks_axes_cluster);
    clear_plot(hObject, h, h.masks_axes_square);
    clear_plot(hObject, h, h.masks_axes_currmask);

    % show the correct masks in masks_image and masks_currmask just for the first mask!
        if h.squares_with_mask(h.chosen_square(1))
            % if this square already has a mask
            h.masks_text_maskname.String = h.mask_names{h.chosen_square(1)};
            h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,h.chosen_square(1))),:,h.chosen_square(1));

            % plot currently selected mask
            if h.cluster
                imagesc(h.mask_cluster_image{ceil(h.chosen_square(1)/h.nof_squares)}, 'Parent', h.masks_axes_cluster);
            end
            imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);
            imagesc(h.mask_array{h.chosen_square(1)}(:,:,1),'Parent',h.masks_axes_currmask);
        else
            % if no mask is setup for this square
            h.masks_text_maskname.String = 'no mask selected';
            h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,h.chosen_square(1))),:,h.chosen_square(1));

        end
        % set the CLims for circular clormaps
%         if length(unique(h.mask_image_square{h.chosen_square(1)})) == 2
%             % so that something is visible even though just two masks
%             h.masks_axes_cluster.CLim = [0, 2];
%             h.masks_axes_square.CLim = [0, 2];
%         else
%             % for more masks
%             h.masks_axes_cluster.CLim = [0, 1];
%             h.masks_axes_square.CLim = [0, 1];
%         end
        % circular colormaps for cluster and square
        h.masks_axes_cluster.Visible = 'off';
        h.masks_axes_cluster.Colormap = ycolormap('magma2'); %'twilight'
        h.masks_axes_square.Visible = 'off';
        h.masks_axes_square.Colormap = ycolormap('magma2'); %'twilight'
        % other colormap for mask
        h.masks_axes_currmask.Visible = 'off';
        h.masks_axes_currmask.CLim = [0, 1];
        h.masks_axes_currmask.Colormap = ycolormap('magma2');
    guidata(hObject,h);

function masks_listbox_cluster_Callback(hObject, ~, h)
    chosen_x_index = get(hObject,'Value');
    h.chosen_cluster = chosen_x_index;
    h.chosen_square = zeros(h.nof_squares*length(h.chosen_cluster),1);
    for n = 1:length(h.chosen_cluster)
        h.chosen_square((h.nof_squares*(n-1)+1):(h.nof_squares*n)) = (h.nof_squares*(h.chosen_cluster(n)-1) + 1):(h.nof_squares*h.chosen_cluster(n));
    end
%     disp(strjoin(['chosen cluster:', strjoin(string(h.nof_squares*(h.chosen_cluster-1)+1))]));
    h.masks_listbox_square.Value = h.chosen_square;

    % delete plots
    clear_plot(hObject, h, h.masks_axes_cluster);
    clear_plot(hObject, h, h.masks_axes_square);
    clear_plot(hObject, h, h.masks_axes_currmask);

    % show the correct masks in masks_image and masks_currmask just for the first mask!
        if h.squares_with_mask(h.chosen_square(1))
            % if this square already has a mask
            h.masks_text_maskname.String = h.mask_names{h.chosen_square(1)};
            h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,h.chosen_square(1))),:,h.chosen_square(1));

            % plot currently selected mask
            imagesc(h.mask_cluster_image{h.chosen_cluster(1)},'Parent',h.masks_axes_cluster);
            imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);
            imagesc(h.mask_array{h.chosen_square(1)}(:,:,1),'Parent',h.masks_axes_currmask);

        else
            % if no mask setup for this square
            h.masks_text_maskname.String = 'no mask selected';
            h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,h.chosen_square(1))),:,h.chosen_square(1));
        end
%         % set the CLims
%         if length(unique(h.mask_image_square{h.chosen_square(1)})) == 2
%             % so that something is visible even though just two masks
%             h.masks_axes_cluster.CLim = [0, 2];
%             h.masks_axes_square.CLim = [0, 2];
%         else
%             % for more masks
%             h.masks_axes_cluster.CLim = [0, 1];
%             h.masks_axes_square.CLim = [0, 1];
%         end
        % circular colormaps for cluster and square
        h.masks_axes_cluster.Visible = 'off';
        h.masks_axes_cluster.Colormap = ycolormap('magma2'); %'twilight'
        h.masks_axes_square.Visible = 'off';
        h.masks_axes_square.Colormap = ycolormap('magma2'); %'twilight'
        % other colormap for mask
        h.masks_axes_currmask.Visible = 'off';
        h.masks_axes_currmask.CLim = [0, 1];
        h.masks_axes_currmask.Colormap = ycolormap('magma2');

    guidata(hObject, h);

function masks_button_loadmask_Callback(hObject, ~, h)
    [mask_filename, mask_pathname] = uigetfile({'*.mat;*.jpg;*.JPG;*.jpeg;*.JPEG;*.png;*.PNG;*.bmp;*.BMP','plausible mask files (*.mat, *.jpg, *.bmp, *.png)'},'Select mask file','./masks');
    if isequal(mask_filename,0)
    % if the user pressed cancel
        disp('User selected Cancel')
        return
    else
        % choose exposure time
        exp_time_temp = str2double(newid('Exposure time [s]:','Please input',1,{num2str(h.preset_exp_time)}));
        disp(exp_time_temp)
        if isempty(exp_time_temp)
            disp('no numeric value given, setting exposure time to preset')
            exp_time_temp = h.preset_exp_time;
        elseif isnan(exp_time_temp)
        % if no valid number given
            disp('no numeric value given, setting exposure time to preset')
            exp_time_temp = h.preset_exp_time;
        else
            disp(['setting exposure time to ', num2str(exp_time_temp), ' s for all chosen squares'])
        end

    % if the user choses a file do a lot of stuff
        if h.cluster
        % if one mask split about multiple squares
            if h.nof_squares == 9
                scale_factor = 3; % for 9 squares
            elseif h.nof_squares == 16
                scale_factor = 4; % for 16 squares
            elseif h.nof_squares == 324
                scale_factor = 18; % for 18*18 squares
            elseif h.nof_squares == 225
                scale_factor = 15; % for 15*15 squares
            else
                disp('invalid nof_squares')
                return
            end
            [mask_array_temp, mask_angles_temp, mask_image_temp] = phal_read_maskfile(mask_filename, mask_pathname, scale_factor);
            for o = 1:length(h.chosen_cluster)
                % store the whole image in one variable
                h.mask_cluster_image{h.chosen_cluster(o)} = mask_image_temp;
%                 for n = scale_factor:-1:1 % somehow needs to count down!
                for n = 1:scale_factor
                    for m = 1:scale_factor
%                     for m = scale_factor:-1:1
                        mask_array_temp2 = mask_array_temp((n-1)*768+1:n*768, (m-1)*768+1:m*768,:);
                        mask_image_temp2 = mask_image_temp((n-1)*768+1:n*768, (m-1)*768+1:m*768);
                        % select the square starting from the first of the cluster counting up
%                         chosen_square_temp = h.nof_squares*h.chosen_cluster(o)-(h.nof_squares-1) + (scale_factor-n)*scale_factor + m - 1;
                        chosen_square_temp = h.nof_squares*h.chosen_cluster(o)-(h.nof_squares-1) + n*scale_factor - scale_factor + m - 1;

                        h.squares_with_mask(chosen_square_temp) = 1;
                        h.mask_names{chosen_square_temp} = mask_filename;
                        h.masks_text_maskname.String = h.mask_names{chosen_square_temp};

                        h.mask_array{chosen_square_temp} = mask_array_temp2;
                        h.mask_image_square{chosen_square_temp} = mask_image_temp2;

                        % write to table after first clearing it for the current mask
                        h.masklist(:,:,chosen_square_temp) = 0;
                        for l=1:length(mask_angles_temp)
                            % write exposure angles
                            h.masklist(l,1,chosen_square_temp) = mask_angles_temp(l);
                            % write exposure times
                            h.masklist(l,2,chosen_square_temp) = exp_time_temp;
                        end
                        h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,chosen_square_temp)),:,chosen_square_temp);
                        % plot into the xy_axes
                        x = [h.square_x(chosen_square_temp)-h.imgwidth/2,h.square_x(chosen_square_temp)+h.imgwidth/2];
                        y = [h.square_y(chosen_square_temp)+h.imgwidth/2,h.square_y(chosen_square_temp)-h.imgwidth/2];
                        hold on
                            imagesc(x,y,h.mask_image_square{chosen_square_temp},'Parent', h.xy_axes_pos)
                        hold off
                        % choose colormap depending on how many masks
                        if length(unique(h.mask_image_square{chosen_square_temp})) == 2
                            h.xy_axes_pos.Colormap = ycolormap('magma2');
                        else
                            h.xy_axes_pos.Colormap = ycolormap('magma2'); %'twilight'
                        end
                    end
                end
            end
        else
        % if same mask for all chosen squares
            [mask_array_temp, mask_angles_temp, mask_image_temp] = phal_read_maskfile(mask_filename, mask_pathname);
            for n = 1:length(h.chosen_square)

                % for every selected square on the substrate
                h.squares_with_mask(h.chosen_square(n)) = 1;
                h.mask_names{h.chosen_square(n)} = mask_filename;
                h.masks_text_maskname.String = h.mask_names{h.chosen_square(n)};

                % save array and image for every square
                h.mask_array{h.chosen_square(n)} = mask_array_temp;
                h.mask_image_square{h.chosen_square(n)} = mask_image_temp;

                % use this to enable or disable the numbers in the edge of squares
                numbers_squared = 0;
                if numbers_squared
                    % set the upper left corner to zero for all masks and put a number for the first mask
                    h.mask_array{h.chosen_square(n)}(1:70, 1:120, :) = 0;
                    h.mask_array{h.chosen_square(n)}(end-69:end, end-119:end, :) = 0;

                    % write the number of the square in NW and SE corners
                    mod100 = mod(h.chosen_square(n), 100);
                    mod10 = mod(mod100, 10);
                    digit1 = mod10; digit1(digit1 == 0) = 10; % ones
                    digit2 = (mod100 - mod10)/10; digit2(digit2 == 0) = 10; % tens
    %                 digit3 = (h.chosen_square(n)-mod100)/100; % hundreds
                    h.mask_array{h.chosen_square(n)}(1:60, 1:60, 1) = h.squarenumbermask(:, :, digit2);
                    h.mask_array{h.chosen_square(n)}(1:60, 61:120, 1) = h.squarenumbermask(:, :, digit1);
                    h.mask_array{h.chosen_square(n)}(end-59:end, end-119:end-60, 1) = h.squarenumbermask(:, :, digit2);
                    h.mask_array{h.chosen_square(n)}(end-59:end, end-59:end, 1) = h.squarenumbermask(:, :, digit1);
                end

                % write stuff to table
                for m=1:length(mask_angles_temp)
                   % write exposure angles
                   h.masklist(m,1,h.chosen_square(n)) = mask_angles_temp(m);
                   % write exposure time
                   h.masklist(m,2,h.chosen_square(n)) = exp_time_temp;
                end
                h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,h.chosen_square(n))),:,h.chosen_square(n));

                % plot in masks_image

                % plot into the xy plot
                x = [h.square_x(h.chosen_square(n))-h.imgwidth/2,h.square_x(h.chosen_square(n))+h.imgwidth/2];
                y = [h.square_y(h.chosen_square(n))+h.imgwidth/2,h.square_y(h.chosen_square(n))-h.imgwidth/2];
                hold on
                imagesc(x,y,h.mask_image_square{h.chosen_square(n)},'Parent', h.xy_axes_pos)
                hold off
            end
        end

        % plot stuff from the last read mask
        clear_plot(hObject, h, h.masks_axes_cluster);
        clear_plot(hObject, h, h.masks_axes_square);
        clear_plot(hObject, h, h.masks_axes_currmask);

        % plot currently selected mask
        if h.cluster
            imagesc(h.mask_cluster_image{h.chosen_cluster(1)},'Parent',h.masks_axes_cluster);
        end
        imagesc(h.mask_array{h.chosen_square(end)}(:,:,1),'Parent',h.masks_axes_currmask);
        imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);

        % set the CLims for circular colormaps
%         if length(unique(h.mask_image_square{h.chosen_square(1)})) == 2
%             % so that something is visible even though just two masks
%             h.masks_axes_cluster.CLim = [0, 2];
%             h.masks_axes_square.CLim = [0, 2];
%         else
            % for more masks
%             h.masks_axes_cluster.CLim = [0, 1];
%             h.masks_axes_square.CLim = [0, 1];
%         end

        % circular colormaps for cluster and square
        h.masks_axes_cluster.Visible = 'off';
        h.masks_axes_cluster.Colormap = ycolormap('magma2'); %'twilight'
        h.masks_axes_square.Visible = 'off';
        h.masks_axes_square.Colormap = ycolormap('magma2'); %'twilight'
        % other colormap for mask
        h.masks_axes_currmask.Visible = 'off';
        h.masks_axes_currmask.CLim = [0, 1];
        h.masks_axes_currmask.Colormap = ycolormap('magma2');

        % estimate exposure time
        h = estimate_exposure_time(hObject, h);

    end
    guidata(hObject,h)

function masks_button_clearmask_Callback(hObject, ~, h)
    for n=1:length(h.chosen_square)
        h.masks_text_maskname.String = 'no mask selected';
        h.squares_with_mask(h.chosen_square(n)) = 0;
        % if there is any mask clear them
        if sum(h.masklist(:,:,h.chosen_square(n)),'all')
            disp('deleting mask')
            h.masklist(:, :, h.chosen_square(n)) = 0;
            h.masks_table.Data = h.masklist(:,:,h.chosen_square(n));
            h.mask_image_square{h.chosen_square(n)} = 0;
            h.mask_array{h.chosen_square(n)} = 0;
        end
        % plot a blank square into the xy plot (deleting would be more trouble)
        x = [h.square_x(h.chosen_square(n))-h.imgwidth/2,h.square_x(h.chosen_square(n))+h.imgwidth/2];
        y = [h.square_y(h.chosen_square(n))+h.imgwidth/2,h.square_y(h.chosen_square(n))-h.imgwidth/2];
        hold on
            imagesc(x,y,h.blackmask,'Parent', h.xy_axes_pos)
        hold off
    end
    clear_plot(hObject, h, h.masks_axes_cluster);
    clear_plot(hObject, h, h.masks_axes_square);
    clear_plot(hObject, h, h.masks_axes_currmask);
    guidata(hObject,h);

function masks_table_CellEditCallback(hObject, eventdata, h)
    if ~isempty(eventdata.Indices)
        input = str2double(eventdata.EditData);
        h.currcell = eventdata.Indices;
        h.currcell_row = h.currcell(1);
        h.currcell_col = h.currcell(2);
        if h.currcell_row > size(h.mask_array{h.chosen_square(1)}, 3)
            % if the cell is not valid for that square don't change value
            return
        end
        if isnan(input)
            errordlg('You must enter a numeric value','Invalid Input','modal')
            return
        else
            % on change in exposure angle or time
            if (h.currcell_col == 1 || h.currcell_col == 2)
                % of all the chosen squares have the same mask name
                if length(unique(h.mask_names(h.chosen_square))) == 1
                    disp('changing the values for all selected squares')
                    for n=1:length(h.chosen_square)
                        h.masklist(h.currcell_row,h.currcell_col,h.chosen_square(n)) = input;
                        h.currangle = h.masklist(h.currcell_row,1,h.chosen_square(n));
                        h.currtime = h.masklist(h.currcell_row,2,h.chosen_square(n));
                    end
                else
                    disp('just changing values for first selected square')
                    h.masklist(h.currcell_row,h.currcell_col,h.chosen_square(1)) = input;
                    h.currangle = h.masklist(h.currcell_row,1,h.chosen_square(1));
                    h.currtime = h.masklist(h.currcell_row,2,h.chosen_square(1));
                end
            else
                disp('invalid column')
            end
            % clear plot
            if isvalid(h.masks_axes_currmask)
                items = h.masks_axes_currmask.Children;
                if ~isempty(items)
                    delete(h.masks_axes_currmask.Children);
                end
            end
            % plot currently selected mask
            imagesc(h.mask_array{h.chosen_square(1)}(:,:,h.currcell_row),'Parent',h.masks_axes_currmask);
            h.masks_axes_currmask.CLim = [0, 1];
            h.masks_axes_currmask.Visible = 'off';
            h.masks_axes_currmask.Colormap = ycolormap('magma2');
        end
    end
    guidata(hObject,h)

function masks_table_CellSelectionCallback(hObject, eventdata, h)
    if ~isempty(eventdata.Indices)
        h.currcell = eventdata.Indices;
        h.currcell_row = h.currcell(1);

        % if that cell is a valid cell for this square
        if h.currcell_row <= size(h.mask_array{h.chosen_square(1)}, 3)
            % clear plot
            if isvalid(h.masks_axes_currmask)
                items = h.masks_axes_currmask.Children;
                if ~isempty(items)
                    delete(h.masks_axes_currmask.Children);
                end
            end
            % plot currently selected mask
            imagesc(h.mask_array{h.chosen_square(1)}(:,:,h.currcell_row),'Parent',h.masks_axes_currmask);
            h.masks_axes_currmask.Visible = 'off';
            h.masks_axes_currmask.CLim = [0, 1];
            h.masks_axes_currmask.Colormap = ycolormap('magma2');
        else
            disp('no mask for this row')
        end
    end
    guidata(hObject,h)

function masks_button_loadmaskset_Callback(hObject, ~, h)
    [filename, path] = uigetfile({'*.mat','plausible preset files (*.mat)'},'Select preset file','./presets');
    if isequal(filename,0)
        disp('User selected Cancel')
        return
    else
        disp('loading file ...')
        load(fullfile(path,filename));
        disp(['File has been saved on version ', num2str(a.phal_version)])
        if h.xy_popupmenu_subsdiam.Value ~= a.xy_popupmenu_subsdiam.Value
            disp(['correcting substrate setting to #', num2str(a.xy_popupmenu_subsdiam.Value)])
            h.xy_popupmenu_subsdiam.Value = a.xy_popupmenu_subsdiam.Value;
        end
        disp('clearing plot and variables')
        h = configure_xy_plot(hObject, h, a.xy_popupmenu_subsdiam.Value, 1);

        disp('loading variables')
        h.mask_cluster_image = a.mask_cluster_image;
        h.mask_image_square = a.mask_image_square;
        h.mask_array = a.mask_array;
        h.masklist = a.masklist;
        h.mask_names = a.mask_names;
        h.squares_with_mask = a.squares_with_mask;
        clear a;

        h = redraw_xy_plot(hObject, h);

        % plot currently selected mask
        if h.squares_with_mask(h.chosen_square)
            imagesc(h.mask_array{h.chosen_square(end)}(:,:,1),'Parent',h.masks_axes_currmask);
            imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);
            imagesc(h.mask_cluster_image{h.chosen_cluster(1)},'Parent',h.masks_axes_cluster);
            h.masks_axes_cluster.Visible = 'off';
            h.masks_axes_square.Visible = 'off';
            h.masks_axes_currmask.Visible = 'off';
%             h.masks_axes_currmask.CLim = [0, 1];
        end

        % estimate exposure time
        h = estimate_exposure_time(hObject, h);

    end
    guidata(hObject, h)

function masks_button_savemaskset_Callback(~, ~, h)
    [filename, path] = uiputfile('./presets/preset0815.mat');
    if isequal(filename,0) || isequal(path,0)
        disp('User clicked Cancel.')
    else
        disp(['User selected ',fullfile(path,filename),' and then clicked Save.'])
        % gui version number, might be important for loading compatibility
        a.phal_version = h.phal_version;
        % substrate diameter has to be matching
        a.xy_popupmenu_subsdiam.Value = h.xy_popupmenu_subsdiam.Value;
        % masks and related info
        a.mask_cluster_image = h.mask_cluster_image;
        a.mask_image_square = h.mask_image_square;
        a.mask_array = h.mask_array;
        a.masklist = h.masklist;
        a.mask_names = h.mask_names;
        a.squares_with_mask = h.squares_with_mask;
        % save the variables
        disp('writing file...')
        save(fullfile(path,filename), 'a', '-v7.3')
        disp(['has been saved as: ', fullfile(path,filename)]);
        clear a;
    end

function masks_button_flipmask_Callback(hObject, ~, h)
if h.cluster
% if clustered depends on the number of clustered squares
    if h.nof_squares == 9
        scale_factor = 3; % for 9 squares
    elseif h.nof_squares == 16
        scale_factor = 4; % for 16 squares
    elseif h.nof_squares == 324
        scale_factor = 18; % for 18*18 squares
    elseif h.nof_squares == 225
        scale_factor = 15; % for 15*15 squares
    else
        disp('invalid nof_squares')
        return
    end

    for o = 1:length(h.chosen_cluster)
        % flip image
        mask_image_temp = fliplr(h.mask_cluster_image{h.chosen_cluster(o)});
        % flip array
        idx = h.nof_squares*h.chosen_cluster(o)-(h.nof_squares-1);
        if h.nof_squares == 9
            mask_array_temp = fliplr([h.mask_array{idx+0}, h.mask_array{idx+1}, h.mask_array{idx+2};...
                               h.mask_array{idx+3}, h.mask_array{idx+4}, h.mask_array{idx+5};...
                               h.mask_array{idx+6}, h.mask_array{idx+7}, h.mask_array{idx+8}]);
        end
        if h.nof_squares == 16
            mask_array_temp = fliplr([h.mask_array{idx+0}, h.mask_array{idx+1}, h.mask_array{idx+2}, h.mask_array{idx+3};...
                               h.mask_array{idx+4}, h.mask_array{idx+5}, h.mask_array{idx+6}, h.mask_array{idx+7};...
                               h.mask_array{idx+8}, h.mask_array{idx+9}, h.mask_array{idx+10}, h.mask_array{idx+11};...
                               h.mask_array{idx+12}, h.mask_array{idx+13}, h.mask_array{idx+14}, h.mask_array{idx+15}]);
        end
        % flip angles
        h.masklist(:, 1, idx:idx+h.nof_squares-1) = fliplr(squeeze(h.masklist(:, 1, idx:idx+h.nof_squares-1)));

        % flip exposure times
        h.masklist(:, 2, idx:idx+h.nof_squares-1) = fliplr(squeeze(h.masklist(:, 2, idx:idx+h.nof_squares-1)));

        % store the whole image in one variable
        h.mask_cluster_image{h.chosen_cluster(o)} = mask_image_temp;
        for n = 1:scale_factor
            for m = 1:scale_factor
                mask_array_temp2 = mask_array_temp((n-1)*768+1:n*768, (m-1)*768+1:m*768,:);
                mask_image_temp2 = mask_image_temp((n-1)*768+1:n*768, (m-1)*768+1:m*768);
                % select the square starting from the first of the cluster counting up
                chosen_square_temp = h.nof_squares*h.chosen_cluster(o)-(h.nof_squares-1) + n*scale_factor - scale_factor + m - 1;

                h.squares_with_mask(chosen_square_temp) = 1;
                h.masks_text_maskname.String = h.mask_names{chosen_square_temp};

                h.mask_array{chosen_square_temp} = mask_array_temp2;
                h.mask_image_square{chosen_square_temp} = mask_image_temp2;

                % write to table
                h.masks_table.Data = h.masklist(1:length(h.masklist(:,1,chosen_square_temp)),:,chosen_square_temp);
                % plot into the xy_axes
                x = [h.square_x(chosen_square_temp)-h.imgwidth/2,h.square_x(chosen_square_temp)+h.imgwidth/2];
                y = [h.square_y(chosen_square_temp)+h.imgwidth/2,h.square_y(chosen_square_temp)-h.imgwidth/2];
                hold on
                    imagesc(x,y,h.mask_image_square{chosen_square_temp},'Parent', h.xy_axes_pos)
                hold off
            end
        end
    end
    imagesc(h.mask_cluster_image{h.chosen_cluster(1)},'Parent',h.masks_axes_cluster);
    imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);
    imagesc(h.mask_array{h.chosen_square(end)}(:,:,1),'Parent',h.masks_axes_currmask);

else
% if not clustered just flip every square
    for n = 1:length(h.chosen_square)
        % for every selected square on the substrate
        h.mask_array{h.chosen_square(n)} = fliplr(h.mask_array{h.chosen_square(n)});
        h.mask_image_square{h.chosen_square(n)} = fliplr(h.mask_image_square{h.chosen_square(n)});

        % plot into the xy plot
        x = [h.square_x(h.chosen_square(n))-h.imgwidth/2,h.square_x(h.chosen_square(n))+h.imgwidth/2];
        y = [h.square_y(h.chosen_square(n))+h.imgwidth/2,h.square_y(h.chosen_square(n))-h.imgwidth/2];
        hold on
        imagesc(x,y,h.mask_image_square{h.chosen_square(n)},'Parent', h.xy_axes_pos)
        hold off
    end
    imagesc(h.mask_array{h.chosen_square(end)}(:,:,1),'Parent',h.masks_axes_currmask);
    imagesc(h.mask_image_square{h.chosen_square(1)},'Parent',h.masks_axes_square);
end
guidata(hObject, h)

%%----------------------------------------------------------------------------------
% substrate position panel (xy)
%%----------------------------------------------------------------------------------

function xy_button_home_Callback(hObject, ~, h)
    disp2('moving x and y stage home');
    currpos = standa_get_abs_pos(h.device_id_x,'xy');
    if currpos ~= 0
       standa_turn_home(h.device_id_x);
    else
        disp('x already home')
    end
    currpos = standa_get_abs_pos(h.device_id_y,'xy');
    if currpos ~= 0
       standa_turn_home(h.device_id_y);
    else
        disp('y already home')
    end

    h = show_xy_position(hObject, h);
    guidata(hObject,h)

function xy_popupmenu_subsdiam_Callback(hObject, ~, h)
    h = configure_xy_plot(hObject, h, h.xy_popupmenu_subsdiam.Value, 1);
    guidata(hObject,h)

function xy_edit_x_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value in mm','Invalid Input','modal')
        h.xy_edit_x.String = h.xy_currpos_x;
        return
    else
        disp('moving x stage')
        standa_move_xy(h.device_id_x, -input); % changed sign
        h = show_xy_position(hObject, h);
    end
    guidata(hObject, h)

function xy_edit_y_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value in mm','Invalid Input','modal')
        h.xy_edit_y.String = h.xy_currpos_y;
        return
    else
        disp('moving y stage')
        standa_move_xy(h.device_id_y,input);
        h = show_xy_position(hObject, h);
    end
    guidata(hObject, h)

function xy_button_xplus1_Callback(hObject, ~, h)
    currpos = standa_get_abs_pos(h.device_id_x,'xy');
    newpos = currpos - 1; %changed sign
    disp('moving x stage')
    standa_move_xy(h.device_id_x, newpos);
    h = show_xy_position(hObject, h);
    guidata(hObject, h)

function xy_button_xminus1_Callback(hObject, ~, h)
    currpos = standa_get_abs_pos(h.device_id_x,'xy');
    newpos = currpos + 1;%changed sign
    disp('moving x stage')
    standa_move_xy(h.device_id_x,newpos);
    h = show_xy_position(hObject, h);
    guidata(hObject, h)

function xy_button_yplus1_Callback(hObject, ~, h)
    currpos = standa_get_abs_pos(h.device_id_y,'xy');
    newpos = currpos + 1;
    disp('moving y stage')
    standa_move_xy(h.device_id_y,newpos);
    h = show_xy_position(hObject, h);
    guidata(hObject, h)

function xy_button_yminus1_Callback(hObject, ~, h)
    currpos = standa_get_abs_pos(h.device_id_y,'xy');
    newpos = currpos - 1;
    disp('moving y stage')
    standa_move_xy(h.device_id_y,newpos);
    h = show_xy_position(hObject, h);
    guidata(hObject, h)

function xy_axes_pos_ButtonDownFcn(~, ~, h)
pos = get(h.xy_axes_pos,'CurrentPoint');
disp(pos)
disp(['You clicked X:',num2str(pos(1)),', Y:',num2str(pos(2))]);

function xy_edit_movetosquare_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        h.xy_edit_movetosquare.String = '';
        return
    elseif round(input) < 1
        disp(['invalid square number please give a value between 0 and ', num2str(length(h.square_x))])
        h.xy_edit_movetosquare.String = '';
    elseif ~(round(input) <= length(h.square_x))
        disp(['invalid square number, maximum is ', num2str(length(h.square_x))])
        h.xy_edit_movetosquare.String = '';
    else
        input = round(input);
        disp(['moving to square #', num2str(input)])
        standa_move_xy(h.device_id_x, -(h.square_x(input) - h.stage_offset_x)); % changed sign
        standa_move_xy(h.device_id_y, h.square_y(input) - h.stage_offset_y);
        h = show_xy_position(hObject, h);
    end
    guidata(hObject, h)

function xy_checkbox_whitemask_Callback(hObject, ~, h)
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        h.xy_checkbox_blackmask.Value = 0;
        h.xy_checkbox_showimage.Value = 0;
        disp('now showing white image')
        fullscreen(h.whitemask, h.screen_no);
    else
        closescreen();
    end
    guidata(hObject, h)

function xy_checkbox_blackmask_Callback(hObject, ~, h)
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        h.xy_checkbox_whitemask.Value = 0;
        h.xy_checkbox_showimage.Value = 0;
        disp('now showing black square')
        fullscreen(h.blackmask, h.screen_no);
    else
        closescreen();
    end
    guidata(hObject, h)

function xy_checkbox_showimage_Callback(hObject, ~, h)
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        if h.squares_with_mask(h.chosen_square(1))
            h.xy_checkbox_whitemask.Value = 0;
            h.xy_checkbox_blackmask.Value = 0;
            disp('now showing image')
            fullscreen(rot90(h.mask_image_square{h.chosen_square(1)}, -1), h.screen_no);
        else
            disp('no mask for the selected square')
        end
    else
        closescreen();
    end
    guidata(hObject, h)

function xy_checkbox_led_on_Callback(hObject, ~, h)
    % if other checkbox is enabled disable it first
    if h.run_checkbox_led_control.Value
        h.run_checkbox_led_control.Value = 0;
        if isfield(h, 'serial_led')
            fclose(h.serial_led);
        end
        h.led_enable = 0;
    end
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        if ~isempty(strfind(cell2mat(seriallist), h.serialport_led))
            if isfield(h, 'serial_led')
                fclose(h.serial_led);
            end
            disp('connecting to LED driver')
            % Connect to instrument object
            h.serial_led = serial(h.serialport_led, 'BaudRate', 9600, 'DataBits', 8, 'StopBits', 2, 'Parity', 'none');
            fopen(h.serial_led);
            % ask for source name
            fprintf(h.serial_led,'*IDN?');
            sourcename = fscanf(h.serial_led);
            disp(['Connected to ' sourcename])
            h.led_enable = 1;
            % remote mode
            fprintf(h.serial_led,'SYST:REM');
            % output 6V
            fprintf(h.serial_led,'INST P6V');
            % recall stored values
            fprintf(h.serial_led,'*RCL 1');
            % switch on LED
            fprintf(h.serial_led,'OUTPut:STATe ON');
            % manually set current and voltage
    %         fprintf(h.serial_led,'SOURce:VOLTage 4.0');
    %         fprintf(h.serial_led,'SOURce:CURRent 0.1');
        else
            disp('could not find LED driver')
            h.xy_checkbox_led_on.Value = 0;
        end
    else
        h.led_enable = 0;
        disp('Switching off LED!')
        if isfield(h, 'serial_led')
            try
                fprintf(h.serial_led,'OUTPut:STATe OFF');
                fclose(h.serial_led);
            catch
                delete(h.serial_led);
            end
        end
    end
    guidata(hObject, h);

function xy_table_samplenames_CellEditCallback(hObject, eventdata, h)
    if ~isempty(eventdata.Indices)
        input = char(eventdata.EditData);
        h.currcell = eventdata.Indices;
        h.currcell_row = h.currcell(1);
        h.currcell_col = h.currcell(2);
        if sum(strcmp(h.samplenames, input))
            disp('sample name already exists grmlgrml')
        end
        % change the sample name in the table
        if h.currcell_col == 1
            for n = 1:length(h.xy_axes_pos.Children)
                % find axes children that are text
                if ~isequal(h.xy_axes_pos.Children(n).Type, 'text')
                    continue
                end
                % find the text that has the string from the previous sample name
                if isequal(h.xy_axes_pos.Children(n).String, h.samplenames{h.currcell_row})
                    h.xy_axes_pos.Children(n).String = input;
                end
            end
            % save the new sample name in the array
            h.samplenames{h.currcell_row} = input;
        else
            disp('invalid column')
        end
    end
    guidata(hObject,h)

%%----------------------------------------------------------------------------------
% rotation stage position panel (rot)
%%----------------------------------------------------------------------------------

function rot_button_home_Callback(hObject, ~, h)
    disp('rotating Polarizer home');
    standa_turn_home(h.device_id_rot);
    h = show_rot_position(hObject,h);
    guidata(hObject,h)

function rot_button_plus10_Callback(hObject, ~, h)
    standa_turn_rot(h.device_id_rot,10);
    h = show_rot_position(hObject,h);
    guidata(hObject,h)

function rot_button_minus10_Callback(hObject, ~, h)
    standa_turn_rot(h.device_id_rot,-10);
    h = show_rot_position(hObject,h);
    guidata(hObject,h)

function rot_button_zero_Callback(hObject, ~, h)
    disp('thou shalt not zero the stage')
%     disp('zeroing rotation stage')
%     standa_set_zero(h.device_id_rot)
    h = show_rot_position(hObject,h);
    guidata(hObject,h)

function rot_button_zerodeg_Callback(hObject, ~, h)
    disp('rotating Polarizer home');
    standa_turn_home(h.device_id_rot);
    disp('Going to 0 degree of Polarizer');
    standa_turn_rot(h.device_id_rot, h.stage_offset_rot);
    h = show_rot_position(hObject,h);
    guidata(hObject,h)

function rot_edit_set_angle_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        return
    else
        rot_pos_diff = input - h.rot_currpos;
        standa_turn_rot(h.device_id_rot,rot_pos_diff);
        h = show_rot_position(hObject,h);
        guidata(hObject,h)
    end

%%----------------------------------------------------------------------------------
% humidity panel(hum)
%%----------------------------------------------------------------------------------

function hum_checkbox_enable_Callback(hObject, ~, h)
    timerperiod = 4;
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        if ~isempty(strfind(cell2mat(seriallist), h.serialport_arduino))
            if isfield(h, 'serial_arduino')
                try
                    fclose(h.serial_arduino);
                catch
                    delete(h.serial_arduino);
                end
            end
            % open serial connection
            disp('now opening connection to arduino')
            h.serial_arduino = serial(h.serialport_arduino, 'Baudrate',57600, 'InputBufferSize', 512);
            fopen(h.serial_arduino);
            pause(0.5)

            % set target humidity
            fprintf(h.serial_arduino, join(['<<', num2str(h.humidity_target), '>']));
            pause(0.5)
            h.humidity_enabled = 1;
            h.hum_checkbox_control.Visible = 'on';
            disp('connected to arduino')
            guidata(hObject, h);

            % set up figure for plotting humidity
            clear_plot(hObject, h, h.exp_axes);
            h.exp_axes.Visible = 'on';
            plot(timeofday(datetime), h.humidity_target, '+b',...
                timeofday(datetime), h.humidity_target, '+k',...
                timeofday(datetime), 0, '+r',...
                'parent', h.exp_axes)
            legend(h.exp_axes, 'current humidity', 'target humidity', 'exposed square', 'AutoUpdate', 'off');
            xlabel(h.exp_axes, 'time')
            ylabel(h.exp_axes, 'relative humidity [%]')
            ylim(h.exp_axes, 'manual')
            ylim(h.exp_axes, [0, 100])
            h.exp_axes.Color = h.exp_uipanel.BackgroundColor;
            h.exp_axes.YColor = 'white';
            h.exp_axes.XColor = 'white';
            hold(h.exp_axes, 'on')

            % start timer
            h.timer = timer(...
                'ExecutionMode', 'fixedRate', ...       % Run timer repeatedly.
                'Period', timerperiod, ...
                'TimerFcn', {@read_humidity, h});
            if strcmp(get(h.timer, 'Running'), 'off')
                start(h.timer);
            end
        else
            disp('could not find arduino on serial port')
            h.hum_checkbox_enable.Value = 0;
        end
    else
        h.humidity_enabled = 0;
        h.hum_text_humidity.String = '';
        h.hum_text_pressure.String = '';
        h.hum_text_temperature.String = '';
        h.hum_checkbox_control.Visible = 'off';
        disp('now closing connection to arduino')
        clear_plot(hObject, h, h.exp_axes);
        legend(h.exp_axes, 'off')
        h.exp_axes.Visible = 'off';
        if isfield(h, 'serial_arduino')
                try
                    fclose(h.serial_arduino);
                catch
                    delete(h.serial_arduino);
                end
        end
        % stop timer
        if ~isempty(timerfind)
            stop(timerfind('Period', timerperiod));
            delete(timerfind('Period', timerperiod));
        end
    end
    guidata(hObject, h)

function hum_checkbox_control_Callback(hObject, ~, h)
    if ~isfield(h, 'serial_arduino')
        disp('no arduino connected')
        return
    end
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        fprintf(h.serial_arduino, '<<CO>');
        disp('now controlling humidity')
        pause(0.3)
        fprintf(h.serial_arduino, join(['<<', num2str(h.humidity_target), '>']));
        pause(0.3)
    else
        fprintf(h.serial_arduino, '<<CF>');
        disp('disabled humidity control')
    end

function hum_edit_target_Callback(hObject, ~, h)
    input = str2double(hObject.String);
    if isnan(input)
        errordlg('You must enter a numeric value','Invalid Input','modal')
        return
    elseif (input < 10) || (input > 90)
        errordlg('You must enter a value between 10 and 90','Invalid Input','modal')
        return
    else
        h.humidity_target = round(input);
        disp(['humidity manually set to ', num2str(input), ' RH%']);
        % if the control is enabled send the new value to the arduino
        if h.humidity_enabled
            fprintf(h.serial_arduino, join(['<<', num2str(input), '>']));
            pause(0.3)
        end
        guidata(hObject,h)
    end

function hum_edit_port_Callback(hObject, ~, h)
% change the arduino serial port
    if isunix
        h.serialport_arduino = hObject.String;
        disp(['Arduino serial port set to ', hObject.String]);
        disp('If this doesnt work make sure to set chmod 777 on that serial port')
    else % on windows just expect a number
        input = str2double(hObject.String);
        if isnan(input)
            % check if number
            errordlg('You must enter a numeric value','Invalid Input','modal')
            h.hum_edit_port.String = h.serialport_arduino(4:5);
            return
        elseif (input < 1) || (input > 30)
            % check if in reasonable range
            errordlg('You must enter a value between 1 and 30','Invalid Input','modal')
            h.hum_edit_port.String = h.serialport_arduino(4:5);
            return
        elseif floor(input) ~= input
            % check if integer
            errordlg('You must enter an INTEGER value between 1 and 30','Invalid Input','modal')
            h.hum_edit_port.String = h.serialport_arduino(4:5);
            return
        else
            % update port
            h.serialport_arduino = ['COM', num2str(input)];
            disp(['Arduino serial port set to COM', num2str(input)]);
        end
    end
    guidata(hObject, h)

%%----------------------------------------------------------------------------------
% exposure run panel(run)
%%----------------------------------------------------------------------------------
% this is the actual exposure function
%   ||
%   ||
%   \/
function run_button_start_Callback(hObject, ~, h)
    if sum(h.squares_with_mask) == 0
        warndlg('Please choose some masks!','!! N00B !!');
        return
    elseif sum(isnan(h.masklist), 'all')
        warndlg('Please enter valid numbers!','!! N00B !!');
        return
    end
    h.next_square = 0;
    h.cancel_exposure = 0;
    h.pause_exposure = 0;
    guidata(hObject,h);
    global humidity_log

% start documenting everything in a log file
    dt = datetime;
    dtstring = sprintf('%i-%02i-%02i_%02i.%02i',dt.Year, dt.Month, dt.Day, dt.Hour, dt.Minute);
    diary(['./logs/', dtstring, '_cli.log']);
    clear dt dtstring
    disp2('starting exposure')

% cosmectics: change background colors
    clear_plot(hObject, h, h.masks_axes_currmask);
    clear_plot(hObject, h, h.masks_axes_square);
    clear_plot(hObject, h, h.masks_axes_cluster);


% disable unnecessary buttons
    disp2('dis-/enabling buttons for exposure ')
    h = disable_buttons(hObject,h);

% parameters
    exposure_times = squeeze(h.masklist(:,2,:))';     % exposure times, one row per square
    polarization_angles = squeeze(h.masklist(:,1,:))';   % polarization angle, one row per square
    rotation_angles = [polarization_angles(:,1),diff(polarization_angles,[],2)]; % set the first angle absolute, the other relative
    pause_time = 0.5;
% find the squares which have a mask
    squares_to_expose = find(h.squares_with_mask)';

% estimate total exposure time
    h = estimate_exposure_time(hObject, h);
    est_total_time = str2double(h.run_text_exposuretime2.String);
    disp2(['estimated total time: ', num2str(est_total_time), ' min'])

% set black screen
    closescreen();
    if h.cluster
        imshow(h.mask_cluster_image{ceil(squares_to_expose(1)/h.nof_squares)},'Parent',h.masks_axes_cluster);
    end
    imshow(h.mask_image_square{squares_to_expose(1)},'Parent',h.masks_axes_square);
    imshow(h.blackmask,'Parent',h.masks_axes_currmask);
    fullscreen(h.blackmask, h.screen_no);

% rotate to the starting position (0 degree)
    disp2('rotating Polarizer home');
    standa_turn_home(h.device_id_rot);
    disp2('Going to 0 degree of Polarizer');
    standa_turn_rot(h.device_id_rot, h.stage_offset_rot);
    h = show_rot_position(hObject,h);



% wait for substrate
    startsound = load('splat');
    sound(startsound.y, startsound.Fs);
    f = warndlg('Pressing OK will start the exposure!','!! Here we go !!');
    waitfor(f);

% setup progress plot
    if ~h.humidity_enabled
        clear_plot(hObject, h, h.exp_axes);
        h.exp_axes.Visible = 'on';
        plot(timeofday(datetime), 0, '+r', 'parent', h.exp_axes)
        legend(h.exp_axes, 'exposed square', 'AutoUpdate', 'off');
        xlabel(h.exp_axes, 'time')
        ylabel(h.exp_axes, 'exposed square')
        ylim(h.exp_axes, 'manual')
        ylim(h.exp_axes, [0, max(squares_to_expose)])
        h.exp_axes.Color = h.exp_uipanel.BackgroundColor;
        hold(h.exp_axes, 'on')
    else
        ylim(h.exp_axes, [0, max([max(squares_to_expose), 100])])
    end
    if (h.pexphum_enabled && h.humidity_enabled)
        sound(startsound.y, startsound.Fs);
        f = warndlg('Did you connect the humidifier?','!! You are welcome !!');
        waitfor(f);
    end

% DEBUG, uncomment to not start the exposure
%     f = warndlg('Check if the square is in the correct position!','!! Then cancelling !!');
%     waitfor(f);
%     return

% switch on LED
    if h.led_enable
        % display warning message for UV exposure
        if h.run_popup_presets.Value == 4
            sound(startsound.y, startsound.Fs);
            f = warndlg('UV LED. put on GOGGLES, CLOSE CURTAINS and put WARNING SIGNS!','!! Warning: may cause skin cancer !!');
            waitfor(f);
            sound(startsound.y, startsound.Fs);
            f = warndlg('Did you flush with nitrogen?','!! You are welcome !!');
            waitfor(f);
        end
        disp2('switching on the LED')
        fprintf(h.serial_led,'OUTPut:STATe ON');
    else
        sound(startsound.y, startsound.Fs);
        f = warndlg('Please switch on the LED','!! Switch on the LED !!');
        waitfor(f);
    end

% Start timer
    process_timer = tic;



%%- EXPOSURE --------------------------------------------------------------
    try
        % loop through the squares that have a mask
        for currsquare = squares_to_expose
            % move to new xy position
            standa_move_xy(h.device_id_x, -(h.square_x(currsquare) - h.stage_offset_x));
            standa_move_xy(h.device_id_y, h.square_y(currsquare) - h.stage_offset_y);
            h = show_xy_position(hObject, h);
            % plot the currently exposed square in progress plot
            plot(h.exp_axes, timeofday(datetime), currsquare, '+r')

            % update masks plots
            if h.cluster
                imshow(h.mask_cluster_image{ceil(currsquare/h.nof_squares)},'Parent',h.masks_axes_cluster);
            end
            imshow(h.mask_image_square{currsquare},'Parent',h.masks_axes_square);

            % expose for every mask of this square
            for n = 1:size(rotation_angles,2)

                % check if there is nothing more to expose at this square
                % (either in exposure time or empty masks)
                if ~sum(exposure_times(currsquare, n:end))
                   disp2('no more exptimes for this square, skipping to the next one')
                   n = n-1; %to rotate back just as many angles as we had rotated to
                   break
                elseif ~sum(h.mask_array{currsquare}(:, :, n:end), 'all')
                   disp2('no more masks for this square, skipping to the next one')
                   n = n-1; %to rotate back just as many angles as we had rotated to
                   break
                end

                % show square and step number
                disp2(['Square #', num2str(currsquare), ' Step #', num2str(n)]);
                h.exp_text_currsquare.String = ['current square', newline, num2str(find(squares_to_expose==currsquare)), '/', num2str(sum(h.squares_with_mask))];
                h.exp_text_currstep.String = ['current step', newline, num2str(n), '/', num2str(nnz(exposure_times(currsquare,:)))];

                % rotate to the current mask angle
                disp2(['setting angle ', num2str(polarization_angles(currsquare,n)),' degree']);
                standa_turn_rot(h.device_id_rot, rotation_angles(currsquare,n));
                h = show_rot_position(hObject,h);
                pause(pause_time);

                % check if this mask has anything to expose
                if (sum(h.mask_array{currsquare}(:,:,n), 'all') == 0 || exposure_times(currsquare,n) == 0)
                    disp2('no exposure at this angle, skipping')
                    continue
                end

                % set image and show mask, rotated by -90 degree for image and +90? for GUI
                imshow(h.mask_array{currsquare}(:,:,n), 'Parent', h.masks_axes_currmask);
                fullscreen(rot90(h.mask_array{currsquare}(:,:,n),-1), h.screen_no);

                % start exposure count
                exposure_timer = tic;
                exposure_timer_pause = 0;

                % exposure
                while (toc(exposure_timer)+exposure_timer_pause) < exposure_times(currsquare,n)
                    % update the times
                    h.exp_text_exposuretime.String = ['elapsed exposure', newline, num2str(round(toc(exposure_timer)+exposure_timer_pause)), ' s'];
                    h.exp_text_elapsedtime.String = ['elapsed time', newline, num2str(round(toc(process_timer)/60)), ' min'];

                    % estimate time
                    % estimated time to go by fraction of squares and steps done per total process time
                    est_remaining_time = est_total_time - toc(process_timer)/60; % in min
                    h.exp_text_timeleft.String = ['est. time left', newline, num2str(round(est_remaining_time)), ' min'];

                    h = guidata(hObject);
                    % check if paused
                    if h.pause_exposure

                        % record the already elapsed time
                        exposure_timer_pause = toc(exposure_timer);

                        % set black screen
                        fullscreen(h.blackmask, h.screen_no);
%                         imshow(h.blackmask,'Parent',h.exp_axes_image);

                        % wait for resume
                        while h.pause_exposure
                            h = guidata(hObject);
                            % check if need to cancel
                            if h.cancel_exposure
                                h.pause_exposure = 0;
                                h.exp_button_pause.String = 'pause exposure';
                                break
                            end
                            pause(0.5)
                        end

                        % check if need to cancel
                        if h.cancel_exposure
                            break
                        end

                        % reset image and show mask, rotated by -90° !!
%                         imshow(rot90(h.mask_array{currsquare}(:,:,n),-1),'Parent',h.exp_axes_image);
                        fullscreen(rot90(h.mask_array{currsquare}(:,:,n),-1), h.screen_no);

                        % restart exposure count
                        exposure_timer = tic;
                    end

                    % check if need to cancel
                    if h.cancel_exposure
                        break
                    end

                    % check if next square has been chosen
                    if h.next_square
                        disp2('breaking exposure loop')
                        break
                    end
                    pause(0.05)
                end

                % set black screen
                fullscreen(h.blackmask, h.screen_no);
%                 imshow(h.blackmask,'Parent',h.exp_axes_image);

                % check if cancelled in exposure loop
                if h.cancel_exposure
                    disp2('jumping out of current step loop')
                    break
                end

                % check for button next square
                if h.next_square
                    disp2('changing to next square')
                    h.next_square = 0;
                    break
                end
            end

            % check if cancelled in square loop
            if h.cancel_exposure
                disp2('jumping out of current square loop')
                break
            end

            % rotate back to initial position or 180 degrees, whatever is closer
            if sum(rotation_angles(currsquare,1:n)) > 90
                % if we are beyond 90 degree do rotate forward to 180 because it is faster
                disp2(['Rotating forward ', num2str(180-sum(rotation_angles(currsquare,1:n))),' degree']);
                standa_turn_rot(h.device_id_rot, 180-sum(rotation_angles(currsquare,1:n)));
            elseif sum(rotation_angles(currsquare,1:n)) == 0
                % if no rotation happened we do not need to rotate back
                disp2('No backrotation needed');
            else
                disp2(['Rotating back ', num2str(-sum(rotation_angles(currsquare,1:n))),' degree']);
                standa_turn_rot(h.device_id_rot, -sum(rotation_angles(currsquare,1:n)));
            end
            h = show_rot_position(hObject,h);

            % set the next current when moving to the next cluster
            if h.multicurrent_index && (mod(currsquare, h.nof_squares) == 0) && h.cluster
                % if not already at the max value jump to the next current
                if ~(h.multicurrent_index == length(h.preset_multicurrent))
                    h.multicurrent_index = h.multicurrent_index + 1;
                    disp(['setting current ', num2str(h.preset_multicurrent(h.multicurrent_index), '%1.1f'), ' A'])
                    fprintf(h.serial_led,['SOURce:CURRent ', num2str(h.preset_multicurrent(h.multicurrent_index), '%1.1f')]);
                end
            end
        end
    catch ME
        %  in case an error occurs, notify me
        disp2('some program error during exposure')
        phal_sendmail('Exposure threw an error', 'some error', h.recipient1_email);
        rethrow(ME)
    end
%%-------------------------------------------------------------------------
% switch off LED
    if h.led_enable
        disp2('switching off LED')
        fprintf(h.serial_led,'OUTPut:STATe OFF');
    end

% show elapsed time
    disp2(['total process time: ', num2str(round(toc(process_timer)/60,1)), ' min'])
    disp2(['beforehand estimated time: ' num2str(round(est_total_time,1)), ' min'])

% adapt plots and close mask
    closescreen();
    if h.cluster
        imshow(h.mask_cluster_image{ceil(squares_to_expose(1)/h.nof_squares)},'Parent',h.masks_axes_cluster);
    end
    imshow(h.mask_image_square{squares_to_expose(1)},'Parent',h.masks_axes_square);
    imshow(h.blackmask,'Parent',h.masks_axes_currmask);

% rotate to the starting position (0 degree)
    disp2('rotating Polarizer home');
    standa_turn_home(h.device_id_rot);
    disp2('Going to 0 degree of Polarizer');
    standa_turn_rot(h.device_id_rot, h.stage_offset_rot);
    h = show_rot_position(hObject,h);

% move xy back to zero
    standa_move_xy(h.device_id_x, 0);
    standa_move_xy(h.device_id_y, 0);
    h = show_xy_position(hObject, h);

% post exposure humdification, saving and notification
if ~h.cancel_exposure
    % post exposure humidification
    if (h.pexphum_enabled && h.humidity_enabled)
        disp2('starting post exposure humidification')
        h.humidity_target = h.pexphum_humidity;
        h.hum_edit_target.String = h.pexphum_humidity;
        h.exp_text_currstep.String = ['current step', newline, 'humidification'];
        disp2(['humidity set to ', num2str(h.pexphum_humidity), ' RH%']);
        fprintf(h.serial_arduino, join(['<<', num2str(h.pexphum_humidity), '>']));
        pause(0.3)
        pexphum_timer = tic;
        while (toc(pexphum_timer) < h.pexphum_time)
            h.exp_text_exposuretime.String = ['elapsed postexp', newline, num2str(round(toc(pexphum_timer)/60)), ' min'];
            h.exp_text_elapsedtime.String = ['elapsed time', newline, num2str(round((toc(process_timer)+toc(pexphum_timer))/60)), ' min'];
            h.exp_text_timeleft.String = ['time left', newline, num2str(round((h.pexphum_time-toc(pexphum_timer))/60)), ' min'];
            h = guidata(hObject);
            if h.cancel_exposure
                disp2('user pressed cancel');
                break
            end
            pause(1)
        end
        disp2('post exposure humidification done')
        disp2('setting reasonable humidity value')
        fprintf(h.serial_arduino, '<<40>');
        h.humidity_target = 40;
        h.hum_edit_target.String = '40';
    else
        disp2('no post exposure humidification')
    end

    % save humidity log
    if h.humidity_enabled
        disp2('saving humidity log')
        dt = datetime;
        dtstring = sprintf('%i-%02i-%02i_%02i.%02i',dt.Year, dt.Month, dt.Day, dt.Hour, dt.Minute);
        save(['./logs/', dtstring, '_humidity_log.mat'], 'humidity_log');
    end

    % export image with all masks
    temp_axes = getframe(h.xy_axes_pos);
    temp_image = frame2im(temp_axes);
    dt = datetime;
    dtstring = sprintf('%i-%02i-%02i_%02i.%02i',dt.Year, dt.Month, dt.Day, dt.Hour, dt.Minute);
    imwrite(temp_image, ['./logs/', dtstring, '_exposure_masks.png']);
    % export image with history of squares and humidity
        % cut out a part with the axis (adding +80 px margin)
        h.exp_axes.Units = 'pixels';
        pos = h.exp_axes.Position;
        marg = 30;
        rect = [-marg, -marg, pos(3)+marg, pos(4)+marg];
        temp_axes = getframe(h.exp_axes, rect);
        h.exp_axes.Units = 'normalized';
    temp_image = frame2im(temp_axes);
    imwrite(temp_image, ['./logs/', dtstring, '_exposure_log.png']);
    clear temp_axes temp_image
    disp2('saved masks and history in ./logs/')

    % send message
    if (h.notification_enabled || h.notification2_enabled)
        message = ['total time elapsed: ', num2str(round(toc(process_timer)/60)), ' min'];
        clear process_timer
        disp2(message)
        finalsound = load('gong'); %handel, laughter, chirp, splat, train
        sound(finalsound.y, finalsound.Fs);
        if h.notification_enabled
            phal_sendmail('Exposure is done', message, h.recipient1_email);
            h.notification_enabled = 0;
        end
        if h.notification2_enabled
            phal_sendmail('Exposure is done', message, h.recipient2_email);
            h.notification2_enabled = 0;
        end
    end

% reset cancel flag
elseif h.cancel_exposure
    disp2('not sending message because cancelled')
    h.cancel_exposure = 0;
end

% reenable buttons
    h = enable_buttons(hObject,h);

% cosmetics: reset colors and text
    h.exp_text_elapsedtime.String = '';
    h.exp_text_exposuretime.String = '';
    h.exp_text_timeleft.String = '';
    h.exp_text_currstep.String = '';
    h.exp_text_currsquare.String = '';

    disp2('!! Done !! Have fun with your samples !!');
    diary off

    guidata(hObject,h);

function run_checkbox_pexphum_Callback(hObject, ~, h)
if ~h.humidity_enabled
    disp('Make sure to enable humidity control!')
end
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        disp('post exposure humidification enabled')
        h.pexphum_enabled = 1;
    else
        disp('post exposure humidification disabled')
        h.pexphum_enabled = 0;
    end
    guidata(hObject, h);

function run_checkbox_led_control_Callback(hObject, ~, h)

% if other LED checkbox is enabled
    if h.xy_checkbox_led_on.Value
        h.xy_checkbox_led_on.Value = 0;
        if isfield(h, 'serial_led')
            fprintf(h.serial_led,'OUTPut:STATe OFF');
            fclose(h.serial_led);
        end
        h.led_enable = 0;
    end
    % if checkbox
    if (get(hObject, 'Value') == get(hObject, 'Max'))
        if ~isempty(strfind(cell2mat(seriallist), h.serialport_led))
            if isfield(h, 'serial_led')
                fclose(h.serial_led);
            end
            disp('connecting to LED driver')
            % Connect to instrument object
            h.serial_led = serial(h.serialport_led, 'BaudRate', 9600, 'DataBits', 8, 'StopBits', 2, 'Parity', 'none');
            fopen(h.serial_led);
            % ask for source name
            fprintf(h.serial_led,'*IDN?');
            sourcename = fscanf(h.serial_led);
            disp(['Connected to ' sourcename])
            h.led_enable = 1;
            % remote mode
            fprintf(h.serial_led,'SYST:REM');
            % output 6V <== I forgot why
            fprintf(h.serial_led,'INST P6V');
            if h.run_popup_presets.Value == 5
                % if using preset
                disp('Using preset 1')
                fprintf(h.serial_led,'*RCL 1'); % recall preset 1 or '*RCL 2' for preset 2
            else
                % else use preset voltage or current
                disp(['Setting: ', num2str(h.preset_current, '%1.2f'), 'A ', num2str(h.preset_voltage, '%1.2f'), 'V'])
                fprintf(h.serial_led,['SOURce:CURRent ', num2str(h.preset_current, '%1.2f')]);
                fprintf(h.serial_led,['SOURce:VOLTage ', num2str(h.preset_voltage, '%1.2f')]);
            end
        else
            disp('could not find LED driver')
            h.run_checkbox_led_control.Value = 0;
        end
    else
        h.led_enable = 0;
        disp('now no automatic control of LED!')
        if isfield(h, 'serial_led')
            try
                fclose(h.serial_led);
            catch
                delete(h.serial_led);
            end
        end
    end
    guidata(hObject, h);

function run_popup_presets_Callback(hObject, ~, h)
% adjust current and voltage
switch h.run_popup_presets.Value
    case 1 % green LED
        disp('Setting current and voltage for GREEN LED (max 1A)')
        h.preset_current = 0.95;
        h.preset_voltage = 3.7;
        h.multicurrent_index = 0;
    case 2 % mint LED
        disp('Setting current and voltage for MINT LED (max 1.2A)')
        h.preset_current = 1.2;
        h.preset_voltage = 3.5;
        h.multicurrent_index = 0;
    case 3 % blue LED
        disp('Setting current and voltage for BLUE LED (max 2A)')
        h.preset_current = 1.95;
        h.preset_voltage = 4;
        h.multicurrent_index = 0;
    case 4 % UV LED
        disp('Setting current and voltage for UV LED (max 1.5A)')
        disp('PUT ON GOGGLES AND PUT CURTAINS EVERYWHERE!!!!!')
        h.preset_current = 1.5;
        h.preset_voltage = 4;
        h.multicurrent_index = 0;
    case 5 % preset 1
        disp('Using Preset 1 of Current Source, your fault if set wrongly.')
        h.multicurrent_index = 0;
    case 6 % multistep
        h.preset_current = 0.1;
        h.preset_voltage = 4;
        % preset LED currents for multiple steps
        h.preset_multicurrent = [0.1, 0.2, 0.5, 1.0, 1.2, 1.5, 2.0];
        h.multicurrent_index = 1;
        disp(['Tuning the current through: ', num2str(h.preset_multicurrent), 'A'])
        disp('IF YOU DONT KNOW WHAT THAT MEANS YOU PROBABLY DONT WANT TO SET THIS!')
    otherwise
        disp('Invalid selection, defaulting to 1')
        h.run_popup_presets.Value = 1;
        h.preset_current = 1;
        h.preset_voltage = 3.5;
        h.multicurrent_index = 0;
end

% change LED settings if it is connected already
if h.led_enable && isfield(h, 'serial_led')
    if h.run_popup_presets.Value <= 4
        fprintf(h.serial_led,['SOURce:CURRent ', num2str(h.preset_current, '%1.12f')]);
        fprintf(h.serial_led,['SOURce:VOLTage ', num2str(h.preset_voltage, '%1.12f')]);
    elseif h.run_popup_presets.Value == 5
        fprintf(h.serial_led,'*RCL 1');
    elseif h.run_popup_presets.Value == 6
        % set current and voltage manually
        fprintf(h.serial_led,['SOURce:CURRent ', num2str(h.preset_multicurrent(1), '%1.1f')]);
        fprintf(h.serial_led,['SOURce:VOLTage ', num2str(h.preset_voltage, '%1.1f')]);
    end
end
guidata(hObject,h)

function run_checkbox_notification_Callback(hObject, ~, h)
if (get(hObject, 'Value') == get(hObject, 'Max'))
    disp('will send email to ', h.recipient1_name, ' once exposure is done')
    h.notification_enabled = 1;
else
    disp('NOT sending an email to ', h.recipient1_name, ' once exposure is done')
    h.notification_enabled = 0;
end
guidata(hObject, h);

function run_checkbox_notification2_Callback(hObject, ~, h)
if (get(hObject, 'Value') == get(hObject, 'Max'))
    disp(['will send email to ', h.recipient2_name, ' once exposure is done'])
    h.notification2_enabled = 1;
else
    disp(['NOT sending an email to ', h.recipient2_name, ' once exposure is done'])
    h.notification2_enabled = 0;
end
guidata(hObject, h);

%%----------------------------------------------------------------------------------
% running exposure panel (exp)
%%----------------------------------------------------------------------------------

function exp_button_cancel_Callback(hObject, ~, h)
    h.cancel_exposure = 1;
    disp('pressed cancel button');
    guidata(hObject,h);

function exp_button_pause_Callback(hObject, ~, h)
if ~h.pause_exposure
    h.pause_exposure = 1;
    disp('pressed pause button');
    h.exp_button_pause.String = 'resume exposure';
    h.exp_button_pause.BackgroundColor = h.color.orange;
else
    h.pause_exposure = 0;
    disp('pressed resume');
    h.exp_button_pause.String = 'pause exposure';
    h.exp_button_pause.BackgroundColor = h.color.gray_medium;
end
    guidata(hObject,h);

function exp_button_nextsquare_Callback(hObject, ~, h)
    h.next_square = 1;
    disp('pressed next square button');
    guidata(hObject,h);

%%----------------------------------------------------------------------------------
% gui control panel (gui)
%%----------------------------------------------------------------------------------
function gui_togglebutton_facts_Callback(hObject, ~, h)
button_state = get(hObject,'Value');
if button_state == get(hObject,'Max')
    h.gui_togglebutton_facts.String = (['Photoalignment v', num2str(h.phal_version)]);
elseif button_state == get(hObject,'Min')
    h.gui_togglebutton_facts.String = 'by Yannick Folwill, 2018-2020';
end

function gui_checkbox_darkmode_Callback(hObject, ~, h)
if (get(hObject, 'Value') == get(hObject, 'Max'))
    h.dark_mode = 1;
    toggle_dark_mode(hObject, h);
else
    h.dark_mode = 0;
    toggle_dark_mode(hObject, h);
end
guidata(hObject, h);

function gui_button_reset_Callback(~, ~, h)
    % stop timer
    if ~isempty(timerfind)
        stop(timerfind('Period', 10));
        delete(timerfind('Period', 10));
    end
    % close the connection to the rotation and translation stages
    if exist('h.device_id_rot','var')
        standa_close(h.device_id_rot);
    end
    if exist('h.device_id_x','var')
        standa_close(h.device_id_x);
    end
    if exist('h.device_id_y','var')
        standa_close(h.device_id_y);
    end
    % close serial connection
    comdevices = instrfind;
    if ~isempty(comdevices)
        fclose(comdevices);
        delete(comdevices);
    end
    clear comdevices
    % close and restart the GUI
    closescreen();
    close(gcf)
    diary off
    phal

function gui_button_quit_Callback(~, ~, h)
    % stop timer
    if ~isempty(timerfind)
        stop(timerfind('Period', 10));
        delete(timerfind('Period', 10));
    end
    % DEBUG
        % save the variables of h to the workspace
%         disp('saving all the variables to the workspace as "h"')
%         assignin('base','h',h);
    % close the connection to the rotation and translation stages
    if exist('h.device_id_rot','var')
        standa_close(h.device_id_rot);
    end
    if exist('h.device_id_x','var')
        standa_close(h.device_id_x);
    end
    if exist('h.device_id_y','var')
        standa_close(h.device_id_y);
    end
    % close serial connection
    comdevices = instrfind;
    if ~isempty(comdevices)
        fclose(comdevices);
        delete(comdevices);
    end
    clear comdevices
    % close the GUI
    closescreen();
    diary off
    close(gcf)

%%----------------------------------------------------------------------------------
% extra functions
%%----------------------------------------------------------------------------------

function h = show_xy_position(hObject, h)
    % clear the old stage position
    if isvalid(h.xy_axes_pos)
        for n = 1:length(h.xy_axes_pos.Children)
            % skip everything that is not a line
            if ~isequal(h.xy_axes_pos.Children(n).Type, 'line')
                continue
            end
            % when it is a line, check for the color blue_light
%             h.xy_axes_pos.Children(n)
            if isequal(h.xy_axes_pos.Children(n).Color, h.color.yellow)
                delete(h.xy_axes_pos.Children(n));
%                 disp('clearing stage from plot')
%                 pause(1)
                break
            end
        end
    end

    h.xy_currpos_x = -standa_get_abs_pos(h.device_id_x,'xy'); % changed sign here
    h.xy_currpos_y = standa_get_abs_pos(h.device_id_y,'xy');
    h.xy_edit_x.String = h.xy_currpos_x;
    h.xy_edit_y.String = h.xy_currpos_y;

    % plot the current stage position
    hold(h.xy_axes_pos, 'on')
    plot(h.xy_currpos_x + h.stage_offset_x, h.xy_currpos_y + h.stage_offset_y, 'o', 'Color', h.color.yellow,...
         'MarkerSize', h.markersize(h.chosen_diam), 'Parent', h.xy_axes_pos);
    hold(h.xy_axes_pos, 'off')
    guidata(hObject, h)

function h = show_rot_position(hObject, h)
    h.rot_currpos = standa_get_abs_pos(h.device_id_rot,'rot') - h.stage_offset_rot;
    h.rot_edit_set_angle.String = h.rot_currpos;
    quiver(-0.9*cosd(h.rot_currpos), -0.9*sind(h.rot_currpos), 2*0.9*cosd(h.rot_currpos),2*0.9*sind(h.rot_currpos),0,...
            'LineWidth', 3, 'Color', h.color.red,'ShowArrowHead','off','Parent',h.rot_axes_currpos);
    h.rot_axes_currpos.XLim = [-1,1];
    h.rot_axes_currpos.YLim = [-1,1];
    h.rot_axes_currpos.Visible = 'off';
    guidata(hObject,h)

function [] = clear_plot(hObject, h, input_axis)
    if isvalid(input_axis)
        items = input_axis.Children;
        if ~isempty(items)
            delete(input_axis.Children);
        end
    end
    guidata(hObject, h);

function h = configure_xy_plot(hObject, h, selected_value, change_flag)
% draws the background of the xy plot with
% * substrate(s)
% * squares
% * square numbers
% * sample names
    switch selected_value
        case 1 % diameter 25, not clustered
            h.cluster = 0;
            h.substrate_diameter = 25;
            h.chosen_diam = 1;
            h.cluster = 0;
            multi_substrate = 0;
            h.square_x = h.imgwidth*[-1, 0, 1, 1.5, 0.5, -0.5, -1.5, -1, 0, 1];
            h.square_y = h.imgwidth*[-1, -1, -1, 0, 0, 0, 0, 1, 1, 1];
        case 2 % diameter 50, not clustered
            h.cluster = 0;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            h.cluster = 0;
            multi_substrate = 0;
            h.square_x = h.imgwidth*[
                                -1, 0, 1,...
                                2.5, 1.5, 0.5, -0.5, -1.5, -2.5,...
                                -3, -2, -1, 0, 1, 2, 3,...
                                3.5, 2.5, 1.5, 0.5, -0.5, -1.5, -2.5, -3.5,...
                                -4, -3, -2, -1, 0, 1, 2, 3, 4,...
                                3.5, 2.5, 1.5, 0.5, -0.5, -1.5, -2.5, -3.5,...
                                -3, -2, -1, 0, 1, 2, 3,...
                                2.5, 1.5, 0.5, -0.5, -1.5, -2.5,...
                                -1, 0, 1];
            h.square_y = h.imgwidth*[...
                                -4, -4, -4,...
                                -3, -3, -3, -3, -3, -3,...
                                -2, -2, -2, -2, -2, -2, -2,...
                                -1, -1, -1, -1, -1, -1, -1, -1,...
                                0, 0, 0, 0, 0, 0, 0, 0, 0,...
                                1, 1, 1, 1, 1, 1, 1, 1,...
                                2, 2, 2, 2, 2, 2, 2,...
                                3, 3, 3, 3, 3, 3,...
                                4, 4, 4] - 16.6; % center is off center by 16.6 mm
        case 3 % diameter 50, clusters with 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            h.cluster = 1;
            multi_substrate = 0;
            h.square_x = h.imgwidth*[
                                -2.5, -1.5, -0.5, -2.5, -1.5, -0.5, -2.5, -1.5, -0.5,...
                                0.5, 1.5, 2.5, 0.5, 1.5, 2.5, 0.5, 1.5, 2.5,...
                                -2.5, -1.5, -0.5, -2.5, -1.5, -0.5, -2.5, -1.5, -0.5,...
                                0.5, 1.5, 2.5, 0.5, 1.5, 2.5, 0.5, 1.5, 2.5];
            h.square_y = h.imgwidth*[...
                                -2.5, -2.5, -2.5, -1.5, -1.5, -1.5, -0.5, -0.5, -0.5,...
                                -2.5, -2.5, -2.5, -1.5, -1.5, -1.5, -0.5, -0.5, -0.5,...
                                0.5, 0.5, 0.5, 1.5, 1.5, 1.5, 2.5, 2.5, 2.5,...
                                0.5, 0.5, 0.5, 1.5, 1.5, 1.5, 2.5, 2.5, 2.5]- 16.6; % center is off center by 16.6 mm
        case 4 % diameter 100, 7x25 mm substrates, not clustered
            h.cluster = 0;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 10;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            h.square_x_offset = 27.5*[0, -sind(60), sind(60), 0, -sind(60), sind(60), 0];
            h.square_y_offset = 27.5*[-1, -cosd(60), -cosd(60), 0, cosd(60), cosd(60), 1];
            for n = 1:7
                h.square_x(((n-1)*10+1):(n*10)) = h.square_x_offset(n) + h.imgwidth*[-1, 0, 1, 1.5, 0.5, -0.5, -1.5, -1, 0, 1];
                h.square_y(((n-1)*10+1):(n*10)) = h.square_y_offset(n) + h.imgwidth*[-1, -1, -1, 0, 0, 0, 0, 1, 1, 1];
            end
        case 5 % diameter 100, 7x25 mm substrates, cluster with 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 9;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            h.square_x_offset = 27.5*[0, -sind(60), sind(60), 0, -sind(60), sind(60), 0];
            h.square_y_offset = 27.5*[-1, -cosd(60), -cosd(60), 0, cosd(60), cosd(60), 1];
            for n = 1:7
                h.square_x(((n-1)*9+1):(n*9)) = h.square_x_offset(n) + h.imgwidth*[-1, 0, 1, -1, 0, 1, -1, 0, 1];
                h.square_y(((n-1)*9+1):(n*9)) = h.square_y_offset(n) + h.imgwidth*[-1, -1, -1, 0, 0, 0, 1, 1, 1];
            end
        case 6 % diameter 100, 7x25 mm substrates, clusters with 16 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 16;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            h.square_x_offset = 27.5*[0, -sind(60), sind(60), 0, -sind(60), sind(60), 0];
            h.square_y_offset = 27.5*[-1, -cosd(60), -cosd(60), 0, cosd(60), cosd(60), 1];
            for n = 1:7
                h.square_x(((n-1)*16+1):(n*16)) = h.square_x_offset(n) + h.imgwidth*[-1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5];
                h.square_y(((n-1)*16+1):(n*16)) = h.square_y_offset(n) + h.imgwidth*repelem([-1.5, -0.5, 0.5, 1.5],4);
            end
        case 7 % diameter 100, not clustered
            h.cluster = 0;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            h.cluster = 0;
            multi_substrate = 0;
            squares_per_row = [6, 10, 12, 14, 16, 16, 16, 18, 18, 18, 18, 16, 16, 16, 14, 12, 10, 6];
            total_squares = sum(squares_per_row);
            disp(['In total got ', num2str(total_squares), ' squares'])
            h.square_x =   [3.75:0.5:6.25,...
                            7.25:-0.5:2.75...
                            2.25:0.5:7.75,...
                            8.25:-0.5:1.75,...
                            1.25:0.5:8.75,...
                            8.75:-0.5:1.25,...
                            1.25:0.5:8.75,...
                            9.25:-0.5:0.75,...
                            0.75:0.5:9.25,...
                            9.25:-0.5:0.75,...
                            0.75:0.5:9.25,...
                            8.75:-0.5:1.25,...
                            1.25:0.5:8.75,...
                            8.75:-0.5:1.25,...
                            1.75:0.5:8.25,...
                            7.75:-0.5:2.25,...
                            2.75:0.5:7.25,...
                            6.25:-0.5:3.75]*10 - h.substrate_diameter/2;
            h.square_y = zeros(length(h.square_x),1);
                h.square_y(:) = 0.75;
                for n = 2:length(squares_per_row)
                    for m = (sum(squares_per_row(1:n-1))+1):sum(squares_per_row(1:n))
                        h.square_y(m) = 0.25 + n*0.5;
                    end
                end
                h.square_y = h.square_y*10 - h.substrate_diameter/2;
        case 8 % diameter 100, 20 clusters, 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 9;
            h.square_x = h.imgwidth*[
                        repmat([repmat(-5.5:1:-3.5,1,3), repmat(-2.5:1:-0.5,1,3), repmat(0.5:1:2.5,1,3), repmat(3.5:1:5.5,1,3)],1,4)...
                        repmat(-1:1:1,1,3), repmat(-8.5:1:-6.5,1,3), repmat(6.5:1:8.5,1,3), repmat(-1:1:1,1,3)];
            h.square_y = h.imgwidth*[...
                        repelem(-8.5,3), repelem(-7.5,3), repelem(-6.5,3),...
                        repmat([repelem(-1,3), repelem(0,3), repelem(1,3)],1,2),...
                        repelem(6.5,3), repelem(7.5,3), repelem(8.5,3),...
                        repmat([repelem(-5.5,3), repelem(-4.5,3), repelem(-3.5,3)],1,4),...
                        repmat([repelem(-2.5,3), repelem(-1.5,3), repelem(-0.5,3)],1,4),...
                        repmat([repelem(0.5,3), repelem(1.5,3), repelem(2.5,3)],1,4),...
                        repmat([repelem(3.5,3), repelem(4.5,3), repelem(5.5,3)],1,4),...
                        ];
        case 9 % diameter 100, 24 clusters with 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 9;
            h.square_x = h.imgwidth*[...
                        repmat([repmat(-5.5:1:-3.5,1,3), repmat(-2.5:1:-0.5,1,3), repmat(0.5:1:2.5,1,3), repmat(3.5:1:5.5,1,3)],1,4),...
                        repmat(-2.5:1:-0.5,1,3), repmat(0.5:1:2.5,1,3),...
                        repmat(-8.5:1:-6.5,1,3), repmat(-8.5:1:-6.5,1,3),...
                        repmat(6.5:1:8.5,1,3), repmat(6.5:1:8.5,1,3),...
                        repmat(-2.5:1:-0.5,1,3), repmat(0.5:1:2.5,1,3)];
            h.square_y = h.imgwidth*[...
            repmat([repelem(-8.5,3), repelem(-7.5,3), repelem(-6.5,3)],1,2),...
                        repmat([repelem(-2.5,3), repelem(-1.5,3), repelem(-0.5,3), repelem(0.5,3), repelem(1.5,3), repelem(2.5,3)],1,2),...
                        repmat([repelem(6.5,3), repelem(7.5,3), repelem(8.5,3)],1,2),...
                        repmat([repelem(-5.5,3), repelem(-4.5,3), repelem(-3.5,3)],1,4),...
                        repmat([repelem(-2.5,3), repelem(-1.5,3), repelem(-0.5,3)],1,4),...
                        repmat([repelem(0.5,3), repelem(1.5,3), repelem(2.5,3)],1,4),...
                        repmat([repelem(3.5,3), repelem(4.5,3), repelem(5.5,3)],1,4),...
                        ];
        case 10 % diameter 100, 36 clusters with 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 9;
            h.square_x = h.imgwidth*...
                        repmat([repmat(-8.5:1:-6.5,1,3), repmat(-5.5:1:-3.5,1,3), repmat(-2.5:1:-0.5,1,3), repmat(0.5:1:2.5,1,3), repmat(3.5:1:5.5,1,3), repmat(6.5:1:8.5,1,3)], 1, 6);
            h.square_y = h.imgwidth*[...
                        repmat([repelem(-8.5,3), repelem(-7.5,3), repelem(-6.5,3)],1,6),...
                        repmat([repelem(-5.5,3), repelem(-4.5,3), repelem(-3.5,3)],1,6),...
                        repmat([repelem(-2.5,3), repelem(-1.5,3), repelem(-0.5,3)],1,6),...
                        repmat([repelem(0.5,3), repelem(1.5,3), repelem(2.5,3)],1,6),...
                        repmat([repelem(3.5,3), repelem(4.5,3), repelem(5.5,3)],1,6),...
                        repmat([repelem(6.5,3), repelem(7.5,3), repelem(8.5,3)],1,6)];
        case 11 % diameter 100, 1 badass clusters with 18*18 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 18*18;
            h.square_x = h.imgwidth*repmat(-8.5:1:8.5,1,18);
            h.square_y = zeros(length(h.square_x),1);
            for n = 1:18
                h.square_y((n-1)*18+1:n*18) = h.imgwidth*((n-1) - 8.5);
            end
        case 12 % diameter 100, 3x3 clusters, 16 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 16;
            h.square_x = h.imgwidth*(...
                        repmat([repmat(-5.5:1:-2.5,1,4), repmat(-1.5:1:1.5,1,4), repmat(2.5:1:5.5,1,4)],1,3));
            h.square_y = h.imgwidth*[...
                        repmat([repelem(-5.5,4), repelem(-4.5,4), repelem(-3.5,4), repelem(-2.5,4)],1,3),...
                        repmat([repelem(-1.5,4), repelem(-0.5,4), repelem(0.5,4), repelem(1.5,4)],1,3),...
                        repmat([repelem(2.5,4), repelem(3.5,4), repelem(4.5,4), repelem(5.5,4)],1,3)];
        case 13 % diameter 100, 12 clusters, 16 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 16;
            h.square_x = h.imgwidth*[...
                        repmat(-3.5:1:-0.5,1,4), repmat(0.5:1:3.5,1,4),...
                        repmat([repmat(-7.5:1:-4.5,1,4), repmat(-3.5:1:-0.5,1,4), repmat(0.5:1:3.5,1,4), repmat(4.5:1:7.5,1,4)],1,2),...
                        repmat(-3.5:1:-0.5,1,4), repmat(0.5:1:3.5,1,4),...
                        ];
            h.square_y = h.imgwidth*[...
                        repmat([repelem(-7.5,4), repelem(-6.5,4), repelem(-5.5,4), repelem(-4.5,4)],1,2),...
                        repmat([repelem(-3.5,4), repelem(-2.5,4), repelem(-1.5,4), repelem(-0.5,4)],1,4),...
                        repmat([repelem(0.5,4), repelem(1.5,4), repelem(2.5,4), repelem(3.5,4)],1,4),...
                        repmat([repelem(4.5,4), repelem(5.5,4), repelem(6.5,4), repelem(7.5,4)],1,2)];
        case 14 % diameter 100, 1 clusters with 15*15 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 0;
            h.nof_squares = 15*15;
            h.square_x = h.imgwidth*repmat(-7:1:7,1,15);
            h.square_y = zeros(length(h.square_x),1);
            for n = 1:15
                h.square_y((n-1)*15+1:n*15) = h.imgwidth*((n-1) - 7);
            end
        case 15 % diameter 100, 7x24 mm SQUARE substrates, clusters with 16 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 16;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            % centers of square substrates:
            h.square_x_offset = 26*[0, -1, 1, 0, -1, 1, 0];
            h.square_y_offset = 13*[-2, -1, -1, 0, 1, 1, 2];
            for n = 1:7
                h.square_x(((n-1)*16+1):(n*16)) = h.square_x_offset(n) + h.imgwidth*[-1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5, -1.5, -0.5, 0.5, 1.5];
                h.square_y(((n-1)*16+1):(n*16)) = h.square_y_offset(n) + h.imgwidth*repelem([-1.5, -0.5, 0.5, 1.5],4);
            end
        case 16 % diameter 100, 7x24 mm SQUARE substrates, clusters with 9 squares
            h.cluster = 1;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 9;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            % centers of square substrates:
            h.square_x_offset = 26*[0, -1, 1, 0, -1, 1, 0];
            h.square_y_offset = 13*[-2, -1, -1, 0, 1, 1, 2];
            for n = 1:7
                h.square_x(((n-1)*9+1):(n*9)) = h.square_x_offset(n) + h.imgwidth*[-1, 0, 1, -1, 0, 1, -1, 0, 1];
                h.square_y(((n-1)*9+1):(n*9)) = h.square_y_offset(n) + h.imgwidth*repelem([-1, 0, 1],3);
            end
        case 17 % diameter 100, 7x25 mm substrates, 9 squares unclustered
            h.cluster = 0;
            h.substrate_diameter = 100;
            h.chosen_diam = 3;
            multi_substrate = 1;
            h.nof_squares = 9;
            h.square_x = zeros(7*h.nof_squares, 1);
            h.square_y = zeros(7*h.nof_squares, 1);
            h.square_x_offset = 27.5*[0, -sind(60), sind(60), 0, -sind(60), sind(60), 0];
            h.square_y_offset = 27.5*[-1, -cosd(60), -cosd(60), 0, cosd(60), cosd(60), 1];
            for n = 1:7
                h.square_x(((n-1)*9+1):(n*9)) = h.square_x_offset(n) + h.imgwidth*[-1, 0, 1, -1, 0, 1, -1, 0, 1];
                h.square_y(((n-1)*9+1):(n*9)) = h.square_y_offset(n) + h.imgwidth*[-1, -1, -1, 0, 0, 0, 1, 1, 1];
            end
        otherwise
            disp(['invalid input: ', num2str(selected_value)])
    end
    % invert y to start from top left and go left to right, top to bottom
    h.square_y = h.square_y(end:-1:1);
    h.square_y_offset = h.square_y_offset(end:-1:1);
    disp(['Selected diameter: ', num2str(h.substrate_diameter), ' mm']);
    % en-/disable the cluster image plot
    if h.cluster
        h.masks_listbox_cluster.Visible = 'on';
        h.masks_text_cluster.Visible = 'on';
    else
        h.masks_listbox_cluster.Visible = 'off';
        h.masks_text_cluster.Visible = 'off';
    end
    h.chosen_square = 1;
    h.chosen_cluster = 1;
    axes(h.xy_axes_pos);

    h.squarenumbers = 1:length(h.square_x);

    % plot
        clear_plot(hObject, h, h.xy_axes_pos);
        % text
        hold on
        text(h.square_x, h.square_y, string(h.squarenumbers), 'FontSize', h.fontsize(h.chosen_diam), 'HorizontalAlignment', 'center', 'Color', 'white');

        % empty squares
        plot(h.square_x, h.square_y, 's', 'Color', h.color.red,'MarkerSize', h.markersize(h.chosen_diam));
        % currently selected square
        h.plothandle_sel_squares = plot(h.square_x(h.chosen_square), h.square_y(h.chosen_square),'s', 'MarkerEdgeColor', h.color.red,'MarkerFaceColor',h.color.red,'MarkerSize', h.markersize(h.chosen_diam));
        % overwrite the selected square back with a number
        text(h.square_x(h.chosen_square), h.square_y(h.chosen_square), string(h.squarenumbers(h.chosen_square)), 'FontSize', h.fontsize(h.chosen_diam), 'HorizontalAlignment', 'center', 'Color', 'white');


    % add a circle the size of the substrate
        ang = 0:0.01:2*pi;
        if multi_substrate
        % add small substrate circle/square/name
            for n = 1:length(h.square_x_offset)
                if (selected_value == 15 || selected_value == 16)
                    % plot squares
                    plot(h.square_x_offset(n), h.square_y_offset(n), 's', 'Color', h.color.red,'MarkerSize', 75);
                else
                    % small circles
                    plot(h.square_x_offset(n)+12.5*(cos(ang)),h.square_y_offset(n)+12.5*(sin(ang)),'Color',h.color.red);
                end
                % sample names
                text(h.square_x_offset(n)-11, h.square_y_offset(n)+13, string(h.samplenames{n}),'Color', 'white')
                h.xy_table_samplenames.Visible = 'on';
                h.samplenames = {'s01', 's02', 's03', 's04', 's05', 's06', 's07'};
                h.xy_table_samplenames.Data = h.samplenames';
            end
        else
            % disable sample names table
            h.xy_table_samplenames.Visible = 'off';
        end
        % large circle
        plot(h.substrate_diameter/2*(cos(ang)),h.substrate_diameter/2*(sin(ang)),'Color', h.color.red);
        clear ang counter maxcount
        h.xy_axes_pos.XLim = [-h.substrate_diameter/2, h.substrate_diameter/2];
        h.xy_axes_pos.YLim = [-h.substrate_diameter/2, h.substrate_diameter/2];
        h.xy_axes_pos.Visible = 'off';
        hold(h.xy_axes_pos, 'off');

        % plot current stage position
        h = show_xy_position(hObject, h);


if change_flag
% when substrate setup has changed reset all the masks and plots
    % reset all the variables
        h.squares_with_mask = zeros(length(h.square_x),1); % reset all the squares to 0
        h.masknames = cell(length(h.square_x),1); % cell with one entry for each square
        h.masklist = zeros(1,1,length(h.square_x)); %
        h.mask_array = cell(length(h.square_x),1); % cell with an entry for each square array
        h.mask_image_square = cell(length(h.square_x),1); % cell with an entry for each square image
        h.mask_cluster_image = cell(length(h.square_x)/length(h.nof_squares)); % cell with an entry for each cluster image

    % update listboxes
        h.masks_listbox_square.String = string(h.squarenumbers);
        if h.cluster
            % if cluster just show one entry per sample
            h.masks_listbox_cluster.String = string(h.squarenumbers(1:h.nof_squares:end));
            h.masks_listbox_cluster.Value = h.chosen_cluster;
            h.masks_listbox_square.Value = h.chosen_square:h.chosen_square+(h.nof_squares-1);
        else
            h.masks_listbox_cluster.String = '';
            h.masks_listbox_square.Value = h.chosen_square;
        end

    % clear masks
        h.masks_text_maskname.String = 'no mask selected';
        h.squares_with_mask(h.chosen_square) = 0;
        clear_plot(hObject, h, h.masks_axes_cluster);
        clear_plot(hObject, h, h.masks_axes_square);
        clear_plot(hObject, h, h.masks_axes_currmask);

end

guidata(hObject, h)

function h = redraw_xy_plot(hObject, h)
% redraws all the masks in the xy plot on update of
% * image width
% * load maskset

    % update all set squares in xy plot
    squares_with_mask = find(h.squares_with_mask)';
    for currsquare = squares_with_mask
        x = [h.square_x(currsquare)-h.imgwidth/2,h.square_x(currsquare)+h.imgwidth/2];
        y = [h.square_y(currsquare)+h.imgwidth/2,h.square_y(currsquare)-h.imgwidth/2];
        hold on
            imagesc(x,y,h.mask_image_square{currsquare},'Parent', h.xy_axes_pos)
        hold off
    end
    guidata(hObject, h);

function [color] = load_colors(~, ~)
    colors = lines(7);
    color.blue = colors(1,:);
    color.orange = colors(2,:);
    color.yellow = colors(3,:);
    color.purple = colors(4,:);
    color.green = colors(5,:);
    color.blue_light = colors(6,:);
    color.red = colors(7,:);
    color.gray_light = [0.94, 0.94, 0.94];
    color.gray_medium = [0.4, 0.4, 0.4];
    color.gray_dark = [0.15, 0.15, 0.15];

%     colormap hot;
    colormap(ycolormap('twilight'));

function [] = disable_exp_buttons(hObject, h)
    h.exp_button_cancel.Enable = 'off';
    h.exp_button_pause.Enable = 'off';
    h.exp_button_nextsquare.Enable = 'off';

    guidata(hObject, h);

function h = disable_buttons(~, h)
    h.masks_button_loadmask.Enable = 'off';
    h.masks_button_clearmask.Enable = 'off';
    h.masks_button_savemaskset.Enable = 'off';
    h.masks_button_loadmaskset.Enable = 'off';
    h.masks_edit_img_width.Enable = 'off';
    h.rot_button_home.Enable = 'off';
    h.rot_button_zero.Enable = 'off';
    h.rot_button_zerodeg.Enable = 'off';
    h.rot_button_plus10.Enable = 'off';
    h.rot_button_minus10.Enable = 'off';
    h.rot_edit_set_angle.Enable = 'off';
    h.xy_button_home.Enable = 'off';
    h.xy_button_xminus1.Enable = 'off';
    h.xy_button_xplus1.Enable = 'off';
    h.xy_button_yminus1.Enable = 'off';
    h.xy_button_yplus1.Enable = 'off';
    h.xy_edit_x.Enable = 'off';
    h.xy_edit_y.Enable = 'off';
    h.xy_edit_movetosquare.Enable = 'off';
    h.xy_popupmenu_subsdiam.Enable = 'off';
    h.xy_checkbox_blackmask.Enable = 'off';
    h.xy_checkbox_whitemask.Enable = 'off';
    h.xy_checkbox_showimage.Enable = 'off';
    h.xy_checkbox_led_on.Enable = 'off';
    h.masks_listbox_square.Enable = 'off';
    h.masks_listbox_cluster.Enable = 'off';
    h.masks_table.Enable = 'off';
    h.led_checkbox.Enable = 'off';
    % enable the active buttons during exposure
    h.exp_button_nextsquare.Enable = 'on';
    h.exp_button_cancel.Enable = 'on';
    h.exp_button_pause.Enable = 'on';
    h.run_checkbox_led_control.Enable = 'off';

function h = enable_buttons(~, h)
    h.masks_button_loadmask.Enable = 'on';
    h.masks_button_clearmask.Enable = 'on';
    h.masks_button_savemaskset.Enable = 'on';
    h.masks_button_loadmaskset.Enable = 'on';
    h.masks_edit_img_width.Enable = 'on';
    h.rot_button_home.Enable = 'on';
    h.rot_button_zero.Enable = 'on';
    h.rot_button_zerodeg.Enable = 'on';
    h.rot_button_plus10.Enable = 'on';
    h.rot_button_minus10.Enable = 'on';
    h.rot_edit_set_angle.Enable = 'on';
    h.xy_button_home.Enable = 'on';
    h.xy_button_xminus1.Enable = 'on';
    h.xy_button_xplus1.Enable = 'on';
    h.xy_button_yminus1.Enable = 'on';
    h.xy_button_yplus1.Enable = 'on';
    h.xy_edit_x.Enable = 'on';
    h.xy_edit_y.Enable = 'on';
    h.xy_edit_movetosquare.Enable = 'on';
    h.xy_popupmenu_subsdiam.Enable = 'on';
    h.xy_checkbox_blackmask.Enable = 'on';
    h.xy_checkbox_whitemask.Enable = 'on';
    h.xy_checkbox_showimage.Enable = 'on';
    h.xy_checkbox_led_on.Enable = 'on';
    h.masks_listbox_square.Enable = 'on';
    h.masks_listbox_cluster.Enable = 'on';
    h.masks_table.Enable = 'on';
    h.led_checkbox.Enable = 'on';
    % disable the inactive buttons after exposure
    h.exp_button_nextsquare.Enable = 'off';
    h.exp_button_cancel.Enable = 'off';
    h.exp_button_pause.Enable = 'off';
    h.run_checkbox_led_control.Enable = 'on';

function read_humidity(~, ~, h)
% careful: hObject here is the timer, not our GUI!
%     try
%         if isfield(h, 'serialconnection')
        global humidity_index
        global humidity_log
%         time_start = datetime('today');
            if h.humidity_enabled

                % read values from arduino
                fprintf(h.serial_arduino, '<<R>');

                try
                % this try-catch might get rid of the reading timeout errors
                    curr_stats = str2num(fscanf(h.serial_arduino));
                    curr_humidity = round(curr_stats(1), 1); % in percent
                    target_humidity_arduino = round(curr_stats(2), 2);
                    curr_pressure = round(curr_stats(3), 2); % in hPa
                    curr_temperature = round(curr_stats(4), 2); % in degreeC
                catch
%                     disp('timeout error, skipping')
                    return
                end

                if curr_humidity > 0 && humidity_index > 1 && curr_humidity < 100
                    humidity_log(humidity_index) = curr_humidity;
                    % display in console just if changing
                    if (abs(humidity_log(humidity_index-1) - curr_humidity) > 1)
                       disp2([num2str(curr_humidity), ' RH%', ', ', num2str(curr_temperature), ' degC', ', ', num2str(curr_pressure), ' hPa'])
                    end
                    plot(h.exp_axes, timeofday(datetime), curr_humidity, '+b',...
                         timeofday(datetime), target_humidity_arduino, '+k')
                end
                humidity_index = humidity_index + 1;

                % update gui
                h.hum_text_humidity.String = ['humidity: ', num2str(curr_humidity), ' RH%'];
                h.hum_text_pressure.String = ['pressure: ', num2str(curr_pressure), ' hPa'];
                h.hum_text_temperature.String = ['temperature: ', num2str(curr_temperature), ' degC'];
            else
                disp('humidity not enabled')
                return

            end

function h = estimate_exposure_time(hObject, h)
% estimate exposure time
    % parameters
    exposure_times = squeeze(h.masklist(:,2,:));        % exposure times, one row per square
    polarization_angles = squeeze(h.masklist(:,1,:))';   % polarization angle, one row per square
    rotation_angles = [polarization_angles(:,1),diff(polarization_angles,[],2)]; % set the first angle absolute, the other relative
% find the squares which have a mask
    squares_to_expose = find(h.squares_with_mask)';

% estimate total exposure time
    % movement
    xpositions = h.square_x(squares_to_expose);
    xposdiffs = [xpositions(1), diff(xpositions(:)')];
    ypositions = h.square_y(squares_to_expose);
    yposdiffs = [ypositions(1), diff(ypositions(:)')];

    % does not respect skipped (empty) exposures
    total_exposure_time = sum(exposure_times, 'all');
    % rotation plus backrotation (estimated 45 degree on average)
    total_rotation_time = (sum(rotation_angles, 'all')+45*length(squares_to_expose))/h.rot_speed;
    total_movement_time = (sum(abs(xposdiffs))+ sum(abs(yposdiffs)))/h.xy_speed;
    est_total_time = total_exposure_time + total_rotation_time + total_movement_time;
    h.run_text_exposuretime2.String = num2str(round(est_total_time/60, 1));
    guidata(hObject,h);

function disp2(inputstr)
% output the input + the current time
    disp([datestr(now, 'HH:MM:SS'), '  ', inputstr])

function toggle_dark_mode(~, h)
% to make the GUI brighter set h.dark_mode=0 and then run toggle_dark_mode(hObject, h)
if h.dark_mode
    color_bg = h.color.gray_dark;
    color_bg2 = h.color.gray_medium;
    color_fg = 'white';
else
    color_bg = h.color.gray_light;
    color_bg2 = h.color.gray_light;
    color_fg = 'black';
end
% change GUI background
a = findall(gcf, 'Tag', 'figure_phal');
% a = findall(gcf)
% return
for n=1:length(a)
    a(n).Color = color_bg;
end
% make all uipanel elements dark
a = findall(gcf, 'Type', 'uipanel');
for n=1:length(a)
    a(n).BackgroundColor = color_bg;
    a(n).ForegroundColor = color_fg;
end
% change uipanel elements
a = findall(gcf, 'Type', 'uibuttongroup');
for n=1:length(a)
    a(n).BackgroundColor = color_bg;
    a(n).ForegroundColor = color_fg;
end
% change checkbox elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'checkbox');
for n=1:length(a)
    a(n).BackgroundColor = color_bg2;
end
% change radio elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'radio');
for n=1:length(a)
    a(n).BackgroundColor = color_bg;
    a(n).ForegroundColor = color_fg;
end
% change text elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'text');
for n=1:length(a)
    a(n).BackgroundColor = color_bg;
    a(n).ForegroundColor = color_fg;
end
% change edit elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'edit');
for n=1:length(a)
    a(n).BackgroundColor = color_bg2;
    a(n).ForegroundColor = color_fg;
end
% change pushbutton elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'pushbutton');
for n=1:length(a)
    a(n).BackgroundColor = color_bg2;
    a(n).ForegroundColor = color_fg;
end
% change togglebutton elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'togglebutton');
for n=1:length(a)
    a(n).BackgroundColor = color_bg2;
    a(n).ForegroundColor = color_fg;
end
% change checkbox elements
a = findall(gcf, 'Type', 'uicontrol', 'Style', 'checkbox');
for n=1:length(a)
    a(n).BackgroundColor = color_bg;
    a(n).ForegroundColor = color_fg;
end

%%- new functions appear below --------------------------------------------
