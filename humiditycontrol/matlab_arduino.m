%%-------------------------------------------------------------------------
%   Humidity sensor matlab serial control test program
%       Send '<<R>' to receive sensor data
%       Send '<<__>' to set humidity level
%
%   Sanket B. Shah, Yannick Folwill (yannick.folwill@posteo.eu)
%%-------------------------------------------------------------------------
clear all;

% This might close all serial ports,
% so run before you make other connections
if ~isempty(instrfind)
     fclose(instrfind);
     delete(instrfind);
end

comPort = 'COM7';

arduino = serial(comPort);
set(arduino,'BaudRate',9600,'TimeOut',100000000);
%%

mode = '<<R>';
hum = 35.43;

fopen(arduino);

mode2 = join(['<<',num2str(hum),'>']);
fprintf(arduino,mode2);
pause(0.3);

out = zeros(10,4);

for k=1:6
    tc = reads(arduino,mode);
    %display(tc);
    test = cell2mat(textscan(tc,'%f %f %f %f','Delimiter',','));
    %display(test);
    out(k,:) = test;
    pause(0.1);
end

hum = 55.67;

mode2 = join(['<<',num2str(hum),'>']);
fprintf(arduino,mode2);
pause(0.3);
% display(reads(arduino,mode));
% pause(0.1);

for k=7:10
    tc = reads(arduino,mode);
    %display(tc);
    test = cell2mat(textscan(tc,'%f %f %f %f','Delimiter',','));
    %display(test);
    out(k,:) = test;
    pause(0.1);
end

fclose(arduino);
