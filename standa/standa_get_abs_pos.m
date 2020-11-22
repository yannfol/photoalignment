function [curr_pos] = standa_get_abs_pos(device_id, stagetype, format)
% Find out the current position and give it out in degree
%   Written for Standa rotation and translation stage to find the current position
%   by Yannick Folwill (yannick.folwill@posteo.eu)
% 
%   28800 is the number of steps for 360 degrees turn of the rotation stage
%   400 steps of the xy-stage are equal to 1 mm 
%   (range is 102 mm and 40865 steps)
%   stagetype can be 'rot' or 'xy'
%   output format can be 'mm' (also used as degree) or 'st' which is steps

% if no output format is selected choose mm
if ~exist('format', 'var')   
    format = 'mm';
elseif ~(strcmp(format, 'mm') || strcmp(format, 'st'))
    disp('not a valid format')
    curr_pos = 0;
    return
end

%   if no stage has been found on standa_open (device_id is zero)
if device_id == 9
    curr_pos = 0;
    switch(stagetype)
        case 'rot'
            disp([datestr(now, 'HH:MM:SS  '), 'no rotation stage connected, cannot get position'])
        case 'xy'
            disp([datestr(now, 'HH:MM:SS  '), 'no xy stage connected, cannot get position'])
        otherwise
            disp([datestr(now, 'HH:MM:SS  '), 'not a valid stage type, choose "rot" or "xy"!'])
    end
    return
end

try
    % to avoid program crashes due to stage crashes
    state = ximc_get_status(device_id);
    switch(stagetype)
        case 'rot'
    %         disp('Position of rotation stage')
            curr_pos = round(state.CurPosition/28800*360,1);
        case 'xy'
    %         disp('Position of translation stage')
            if strcmp(format, 'mm')
                curr_pos = round(state.CurPosition/400,1);
            else
                curr_pos = state.CurPosition;
            end
        otherwise
            disp('Choose a valid stagetype, "rot" or "xy"!')
    end
    % disp(['Current position ', num2str(curr_pos)]);
catch
    if ~isnumeric(device_id)
        disp([datestr(now, 'HH:MM:SS  '), 'not a valid device id: ', device_id])
    else
        disp([datestr(now, 'HH:MM:SS  '), 'somehow the stages screwed up and lost connection, device id: ', device_id])
    end
    ysendmail('standa stage error', 'something screwed up')
    curr_pos = 0;
end