function closescreen()
% CLOSESCREEN Dispose FULLSCREEN() window

global frame_java
try 
    frame_java.dispose(); 
catch
    disp('unable to close fullscreen window');
end

