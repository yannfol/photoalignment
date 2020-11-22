% MATLAB test for XIMC library
% Tested R2014b 32-bit WinXP, R2014b 64-bit Win7, R2014b 64-bit OSX 10.10

[~,maxArraySize]=computer;
is64bit = maxArraySize > 2^31;
if (ispc)
	if (is64bit)
			disp('Using 64-bit version')
			disp('NOTE! Copy ximc.h, libximc.dll, bindy.dll, xiwrapper.dll, wrappers/matlab/libximc_thunk_pcwin64.dll, wrappers/matlab/ximc.m to the current directory')
	else
			disp('Using 32-bit version')
			disp('NOTE! Copy ximc.h, libximc.dll, bindy.dll, xiwrapper.dll and wrappers/matlab/ximcm.h to the current directory')
	end
elseif ismac
	disp('NOTE! Copy libximc.framework to the current directory')
elseif isunix
	disp('Using unix version, check your compilers')
end

if not(libisloaded('libximc'))
    disp('Loading library')
		if ispc
			if (is64bit)
					[notfound,warnings] = loadlibrary('libximc.dll', @ximcm)
			else
					[notfound, warnings] = loadlibrary('libximc.dll', 'ximcm.h', 'addheader', 'ximc.h')
			end
		elseif ismac
			[notfound, warnings] = loadlibrary('libximc.framework/libximc', 'ximcm.h', 'mfilename', 'ximcm.m', 'includepath', 'libximc.framework/Versions/Current/Headers', 'addheader', 'ximc.h')
		elseif isunix
			[notfound, warnings] = loadlibrary('libximc.so', 'ximcm.h', 'addheader', 'ximc.h')
		end
end

device_names = ximc_enumerate_devices_wrap(0);
devices_count = size(device_names,2);
if devices_count == 0
    disp('No devices found')
    return
end
for i=1:devices_count
    disp(['Found device: ', device_names{1,i}]);
end
device_name = device_names{1,1};
disp(['Using device name ', device_name]);

device_id = calllib('libximc','open_device', device_name);
disp(['Using device id ', num2str(device_id)]);

state_s = ximc_get_status(device_id);
disp('Status:'); disp(state_s);

disp('Zeroing engine...');
result = calllib('libximc','command_zero', device_id);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

% disp('Running engine to the right for 5 seconds...');
% result = calllib('libximc','command_left', device_id);
% if result ~= 0
%     disp(['Command failed with code', num2str(result)]);
% end

% pause(2);
calb = struct();
calb.A = 0.1; % arbitrary choice for example, set by user in real scenarios
calb.MicrostepMode = 9; % == MICROSTEP_MODE_FRAC_256
state_calb_s = ximc_get_status_calb(device_id, calb);
disp('Status calb:'); disp(state_calb_s);

% pause(3);

state_s = ximc_get_status(device_id);
disp('Status:'); disp(state_s);
shift = 2*state_s.CurPosition;

disp('Running engine...');
result = calllib('libximc','command_move', device_id, -2400, 0);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

disp('Waiting for stop...');
result = calllib('libximc','command_wait_for_stop', device_id, 100);
if result ~= 0
    disp(['Command failed with code', num2str(result)]);
end

state_s = ximc_get_status(device_id);
disp('Status:'); disp(state_s);

device_id_ptr = libpointer('int32Ptr', device_id);
calllib('libximc','close_device', device_id_ptr);
disp('Done');
% when needed
% unloadlibrary('libximc');
