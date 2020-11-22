function standa_turn_home(device_id)
%   Rotates the rotation stage to the home position
%   Written for Standa 8MPR16-1 precision rotation stage
%   Works as well for Standa XY stage
%   by Yannick Folwill (yannick.folwill@posteo.eu)
%
%   needs to get the device_id to an open connection
%%-------------------------------------------------------------------------

%   if no stage has been found on standa_open (device_id is zero)
if device_id == 9
    disp([datestr(now, 'HH:MM:SS  '), 'no stage connected, cannot rotate home'])
    return
end
fprintf(datestr(now, 'HH:MM:SS  '))
fprintf('Moving Home...');

result = calllib('libximc','command_home', device_id);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

% stop the rotation
fprintf('Waiting for stop...');
result = calllib('libximc','command_wait_for_stop', device_id, 100);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end
fprintf('Done.\n')