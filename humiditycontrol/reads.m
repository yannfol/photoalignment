function [output] = reads(s,command)
% Serial send read request to Arduino
fprintf(s,command);  

% Read value returned via Serial communication 
output = fscanf(s,'%s');

end
