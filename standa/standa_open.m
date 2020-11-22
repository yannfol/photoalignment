function [device_id_rot, device_id_x, device_id_y, devices_count] = standa_open()
%   Open a connection to all found standa stages
%   by Yannick Folwill (yannick.folwill@posteo.eu)
%
%   Gives out the device_id to the open connections
%   result shows 0 if no stages have been found
%%-------------------------------------------------------------------------

[~,maxArraySize]=computer;
is64bit = maxArraySize > 2^31;
if (ispc)
	if (is64bit)
			disp('Using 64-bit Windows version')
	else
			disp('Using 32-bit Windows version')
	end
elseif ismac
	disp('Using mac version')
elseif isunix
	disp('Using unix version, check your compilers')
end

if not(libisloaded('libximc'))
    disp('Loading library')
        if ispc
% 			addpath(fullfile(pwd,'standa/ximc-2.9.14/ximc/win64/wrappers/matlab/'));
			if (is64bit)
% 					addpath(fullfile(pwd,'standa/ximc-2.9.14/ximc/win64/'));
					[notfound, warnings] = loadlibrary('libximc.dll', @ximcm);
			else
% 					addpath(fullfile(pwd,'standa/ximc-2.9.14/ximc/win32/'));
					[notfound, warnings] = loadlibrary('libximc.dll', 'ximcm.h', 'addheader', 'ximc.h');
			end
		elseif ismac
			addpath(fullfile(pwd,'standa/ximc-2.9.14/ximc/'));
			[notfound, warnings] = loadlibrary('libximc.framework/libximc', 'ximcm.h', 'mfilename', 'ximcm.m', 'includepath', 'libximc.framework/Versions/Current/Headers', 'addheader', 'ximc.h');
		elseif isunix
			[notfound, warnings] = loadlibrary('libximc.so', 'ximcm.h', 'addheader', 'ximc.h');
        end
        if ~isempty(notfound)
            disp(notfound)
            return
        end
%         if ~isempty(warnings)
%             disp(warnings)
%         end
end

% just to be sure the connections are closed
standa_close(0)
standa_close(1)
standa_close(2)
standa_close(3)
pause(0.5)

% presetting all the ids to zero in case they are not connected
device_id_rot = 9;
device_id_x = 9;
device_id_y = 9;

device_names = ximc_enumerate_devices_wrap(0);
devices_count = size(device_names,2);

% if no stage is connected just return
if devices_count == 0
    disp('no standa stages connected, setting all device_ids to 9')
    return
end

% sort the device id to the correct name
for i=1:devices_count
    % port name
    disp(['Found device: ', device_names{1,i}]);
    device_id_temp = calllib('libximc','open_device', device_names {1,i});
    
    % real stage name
    % some weird trick for getting parameters: sending a struct with a pointer
    % representing the name of the wished parameter (here stage_name_t, 17 char array)
    dummy_struct = struct('PositionerName',(1:17));
    parg_struct = libpointer('stage_name_t', dummy_struct);
    [result, stage_name] = calllib('libximc','get_stage_name',device_id_temp,parg_struct);
    if result ~= 0
        disp(['Command failed with code', num2str(result)]);
        disp('could not get the stage name')
        stage_name = 0;
    end
    
    % convert to string
    try
        currstagename = char(stage_name.PositionerName(stage_name.PositionerName ~= 0));
    catch
        disp('could not get stage name, maybe stage is used in another application?')
        continue
    end
    disp(['Found stage name: ', currstagename])
    clear parg_struct dummy_struct
    
    % return the device id for the correct stages
    switch currstagename
        case 'rot-stage'
            device_name_rot = currstagename;
            device_id_rot = device_id_temp;
        case 'x-stage'
            device_name_x = currstagename;
            device_id_x = device_id_temp;
        case 'y-stage'
            device_name_y = currstagename;
            device_id_y = device_id_temp;
        otherwise
            disp(['not a valid stage name: ', currstagename])
    end
end
% status_rot = ximc_get_status(device_id_rot);
% status_x = ximc_get_status(device_id_x);
% status_y = ximc_get_status(device_id_y);
% disp('Status: rot');
% disp(status_rot); 
% disp('Status: x');
% disp(status_x); 
% disp('Status: y');
% disp(status_y);

% no idea what this is doing
if device_id_rot == -1
    device_id_ptr = libpointer('int32Ptr', 1);
    calllib('libximc','close_device', device_id_ptr);
    pause(1)
    device_id_rot = calllib('libximc','open_device', device_name_rot);
end
if device_id_x == -1
    device_id_ptr = libpointer('int32Ptr', 1);
    calllib('libximc','close_device', device_id_ptr);
    pause(1)
    device_id_x = calllib('libximc','open_device', device_name_x);
end
if device_id_y == -1
    device_id_ptr = libpointer('int32Ptr', 1);
    calllib('libximc','close_device', device_id_ptr);
    pause(1)
    device_id_y = calllib('libximc','open_device', device_name_y);
end
disp(['Standa Rotation Stage at device id ', num2str(device_id_rot)]);
disp(['Standa x-Stage at device id ', num2str(device_id_x)]);
disp(['Standa y-Stage at device id ', num2str(device_id_y)]);

%%- for DEBUGGING only-----------------------------------------------------
% disp('DEBUGGING: closing all connections')
% standa_close(0);
% standa_close(1);
% standa_close(2);
% standa_close(3);
