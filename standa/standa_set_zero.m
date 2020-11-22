function standa_set_zero(device_id)
%   Set the current position of the rotation stage to zero
%   Written for Standa 8MPR16-1 precision rotation stage
%   Works also for xy stage
%   by Yannick Folwill (yannick.folwill@posteo.eu)
% 
%   needs to get the device_id to an open connection

%   if no stage has been found on standa_open (device_id is zero)
if device_id == 9
    disp([datestr(now, 'HH:MM:SS  '), 'no stage connected, cannot zero'])
    return
end

disp([datestr(now, 'HH:MM:SS  '), 'Zeroing engine...']);
result = calllib('libximc','command_zero', device_id);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

