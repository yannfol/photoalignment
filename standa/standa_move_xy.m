function standa_move_xy(device_id, newpos_mm)
% Rotate the Standa device by angle
%   Written for Standa x and y linear stage
%   by Yannick Folwill (yannick.folwill@posteo.eu)
%
%   400 steps of the xy-stage are equal to 1 mm 
%   (range is 102 mm and 40865 steps)

%   if no stage has been found on standa_open (device_id is zero)
if device_id == 9
    disp([datestr(now, 'HH:MM:SS  '), 'no stage connected, cannot move x or y'])
    return
end

% how many steps for the input
currpos_st = standa_get_abs_pos(device_id, 'xy', 'st');
newpos_st = newpos_mm*400;
tomove_st = round(newpos_st-currpos_st);


% move the number of steps
fprintf(datestr(now, 'HH:MM:SS  '))
fprintf('Moving %.1f mm %d steps ... ', round(tomove_st/400, 1), tomove_st);
result = calllib('libximc','command_movr', device_id, tomove_st, 0);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

% stop the movement
result = calllib('libximc','command_wait_for_stop', device_id, 100);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end
fprintf('Done.\n');
% currpos_st = standa_get_abs_pos(device_id, 'xy', 'st');
% disp(['Now at position ', num2str(currpos_st), ' steps.'])