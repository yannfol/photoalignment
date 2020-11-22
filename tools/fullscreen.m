function fullscreen(image,device_number)
%FULLSCREEN Display fullscreen true colour images
%   FULLSCREEN(C,N) displays matlab image matrix C on display number N
%   (which ranges from 1 to number of screens). Image matrix C must be
%   the exact resolution of the output screen since no scaling in
%   implemented. If fullscreen is activated on the same display
%   as the MATLAB window, use ALT-TAB to switch back.
%
%   If FULLSCREEN(C,N) is called the second time, the screen will update
%   with the new image.
%
%   Use CLOSESCREEN() to exit fullscreen.
%
%   Requires Matlab 7.x (uses Java Virtual Machine), and has been tested on
%   Linux and Windows platforms.
%
%   Written by Pithawat Vachiramon
%
%   Update (23/3/09):
%   - Uses temporary bitmap file to speed up drawing process.
%   - Implemeted a fix by Alejandro Camara Iglesias to solve issue with
%   non-exclusive-fullscreen-capable screens.
%
%   Modified: 
%   15.01.2018 by Sanket B. Shah, for scaling images

ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
gds = ge.getScreenDevices();
try
    height = gds(device_number).getDisplayMode().getHeight();
    width = gds(device_number).getDisplayMode().getWidth();
catch
    disp(['device number ', num2str(device_number), ' does not exist, defaulting to 2'])
    device_number = 2;
    height = gds(device_number).getDisplayMode().getHeight();
    width = gds(device_number).getDisplayMode().getWidth();
end
aspectMonitor = width/height;
aspectImage = size(image,2)/size(image,1);

% Rotate image to fit and match aspect ratio
if aspectMonitor < 1
    if aspectImage > 1
        image = imrotate(image,-90);
        disp('Image rotated 90 deg');
    end
elseif aspectImage < 1
    image = imrotate(image,-90);
    disp('Image rotated 90 deg');
end

% Resize image, add black strips in areas to center image
if aspectMonitor >= aspectImage
    reSca = height/size(image,1);
    strip = abs(floor(0.5*(width - reSca*size(image,2))));
    image = imresize(image,reSca);
    image = padarray(image,[0 strip],'pre');
    image = padarray(image,[0 strip],'post');
else
    reSca = width/size(image,2);
    strip = abs(floor(0.5*(height - reSca*size(image,1))));
    image = imresize(image,reSca);
    image = padarray(image,[strip 0],'pre');
    image = padarray(image,[strip 0],'post');
end

% disp(['Image scaled by ' num2str(reSca)]);

try
    imwrite(image,[tempdir 'display.bmp']);
catch
    error('Image must be compatible with imwrite()');
end

buff_image = javax.imageio.ImageIO.read(java.io.File([tempdir 'display.bmp']));

global frame_java;
global icon_java;
global device_number_java;

if ~isequal(device_number_java, device_number)
    try frame_java.dispose(); end
    frame_java = [];
    device_number_java = device_number;
end
    
if ~isequal(class(frame_java), 'javax.swing.JFrame')
    frame_java = javax.swing.JFrame(gds(device_number).getDefaultConfiguration());
    bounds = frame_java.getBounds(); 
    frame_java.setUndecorated(true);
    icon_java = javax.swing.ImageIcon(buff_image); 
    label = javax.swing.JLabel(icon_java); 
    frame_java.getContentPane.add(label);
%     gds(device_number).setFullScreenWindow(frame_java);
    % new line:
    frame_java.setSize( bounds.height, bounds.width );
    %
    frame_java.setLocation( bounds.x, bounds.y ); 
else
    icon_java.setImage(buff_image);
end
frame_java.pack
frame_java.repaint
frame_java.show