function [] = standa_close(device_id)
%   Closes the connection to the standa rotation stage device_id
%   Written for Standa 8MPR16-1 precision rotation stage to change
%   polarization using half wave plate
%   by Yannick Folwill (yannick.folwill@posteo.eu)
%   
%   Needs the device_id as input


device_id_ptr = libpointer('int32Ptr', device_id);
calllib('libximc','close_device', device_id_ptr);

