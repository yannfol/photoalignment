function standa_turn_rot(device_id, angle_deg)
% Rotate the Standa device by angle
%   Written for Standa 8MPR16-1 precision rotation stage to change
%   polarization using half wave plate
%   by Yannick Folwill (yannick.folwill@posteo.eu)
%
%   The input angle is in DEGREE!
%   The positive rotation direction is counterclockwise! (mathematically positive)
%   28800 is the number of steps for 360 degrees turn of the rotation stage
%%-------------------------------------------------------------------------

%   if no stage has been found on standa_open (device_id is zero)
if device_id == 9
    disp([datestr(now, 'HH:MM:SS  '), 'no stage connected, cannot rotate'])
    return
end

%%-------------------------------------------------------------------------
% MAKE EVERYTHING NEGATIVE if the stage is upside down!
% angle_deg = -angle_deg;
% 
%%-------------------------------------------------------------------------

% how many steps for the input angle
steps = round(angle_deg/360*28800);

% turn by the number of steps
fprintf(datestr(now, 'HH:MM:SS  '))
fprintf('Turning %.1f degree, %d steps ... ', angle_deg, steps);

result = calllib('libximc','command_movr', device_id, steps, 0);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

% stop the rotation
result = calllib('libximc','command_wait_for_stop', device_id, 100);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end
fprintf('Done.\n');