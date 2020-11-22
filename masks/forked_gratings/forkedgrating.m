%% ForkedDiffractionGrating
%
% Core program written by Brett Rojec, 6/12
% Modified by Kiko Galvez, 1/13, 8/13, 7/14, 6/15, 3/16
% Department of Physics and Astronomy, Colgate University.
% Copyright - Not for commercial use
% Modified by Yannick Folwill (yannick.folwill@posteo.eu)
%
% Program designed for making a forked diffraction grating.
% The program is set to load on a Cambridge Correlators SLM
%
% Input parameters:
% "s"=line density 1/s=pixels/line: For s=1: 1/s=~6;
% "ell"=topological charge of the grating. Will generate a Laguerre-Gauss
% type of beam of that charge on first-order diffraction;
% "Nx", "Ny" are the pixel resolutions of the SLM;
% w=width of the beam, for use with amplitude modulation;
% "ampmod" Boolean switch: True= amplitude modulation, False= no amplitude
%   modulation; 
% "phaseblaze" Boolean switch: True= impart phase blazing, 
%   False= impart binary grating;
% "bowmanblaze" Boolean switch: True= apply correction for <2pi phase, per
%   algorithm of Bowman et al Eur. Phys. J. 199, 149-158 (2011);
% "Secondaryscreen" Boolean switch: True= places the image in a screen
%   location tat corresponds to the secondary monitor. Credit to this trick
%   goes to Giovanni Milione, False = image is placed by Matlab on main
%   screen. The parameters of the placement are the "position" coordinates,
%   which depend on the primary screen: Left=distance from left edge of
%   main screen to left edge of the figure. Bot= distance from bottom edge
%   of main screen to bottom edge of the figure.
%
% Generates a png image file that can be loaded onto the SLM.
%
% clear all;
% close all;

%% Definitions
%
s=0.3; % This parameter defines the fringe density. Use s=0-1
ell=1; % This is the value of the topological charge of the LG beam
imfName=join(['forkgrating_binary_o',num2str(ell),'_d',num2str(s),'.png']); % This is the name of the file that has the pattern
sell=num2str(ell);
s2s=num2str(s);
Nx = 3*768; % # of pixels in x-dimension
Ny = 3*768;  % # of pixels in y-dimension
C = ones(Ny,Nx,3); % matrix that will become the image 
w = 200; %half width of the mode
ampmod = false; % True= amplitude modulation; False= no amplitude modulation
phaseblaze = false; %True= phase blazing; False= binary grating
bowmanblaze = false; %True= apply correction for <2pi phase 
Secondaryscreen = false; % True place figure on secondary screen.

%% Phase calculation
% Double loop to calculate the phase of each pixel
A=2^(abs(ell)/2)*sqrt(2/(pi*factorial(abs(ell))))/w^(abs(ell)+1); % Constant
for x = 1:Nx
    for y = 1:Ny
        x0 = Nx/2; % coordinates of the center of the image
        y0 = Ny/2;
        xr=x-x0;
        yr=y-y0;
        r=sqrt(xr^2+yr^2); % radial coordinate
        phi=atan2(yr,xr);  % angular coordinate
        if ampmod % Amplitude modulation
            fudge=r^abs(ell)*exp(-r^2/w^2)/((w*sqrt(ell/2))^abs(ell)*exp(-ell/2));
        else
            fudge=1;
        end
        phi1 = ell*phi + s*(xr); %phase of fork1 at pixel (x,y);
        if phaseblaze % Phase blaze
            r1 = mod(phi1,2*pi)/(2*pi); %phase mod 2 pi in units of 2pi
        else % to do binary grating
            r1 = mod(phi1,2*pi)/(2*pi); %phase mod 2 pi in units of 2pi
            if r1 >=0.5
                r1=0;
            else
                r1=1;
            end
        end
        r1=r1*fudge;
%         r1=1-r1*fudge;  % Reverse scaling
        % Using the Bowman method to correct the blaze to trapezoidal
        if bowmanblaze
            maxphase = 0.4; % max phase of the SLM in units of 2pi
            nslope = 1/maxphase; % new blaze slope (instead of 1)
            xc = (1-1/nslope)/2; %half of dead channels
            if r1<0 || r1>1
                r1=r1;
            end
            x2 = r1;
            if x2 < xc
                r1 = 0;
            elseif x2 > 1-xc;
                r1 = 1;
            else
                r1 = nslope*(x2-xc); % the new blaze
            end
        end
        for i=1:3
            C(y,x,i) = r1; %pixel, 3 colors
        end
%        Ctemp(y,x)=r1;
    end
end
%% Output
%
clims = [0 1];
if Secondaryscreen
    Left=1280; % Pixelwidth of main screen
    Bot=800-Ny; % Main screen height - SLM height in pixels
    position = [Left Bot Nx Ny];
    figure('Position',position,'MenuBar','none');
    axes('Position',[0 0 1 1]); 
else
    figure();
end
imshow(C,clims);
colormap(gray);
axis equal;
axis off;
fileType = 'png';
imwrite(C, imfName, fileType);