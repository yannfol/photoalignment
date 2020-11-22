%% ulam's spiral 

nof_pixels = 768/4;
mask = zeros(nof_pixels, nof_pixels);


spiral_length = length(mask(:));
primes = 1:spiral_length;
primes = isprime(primes);

x_coord = zeros(spiral_length,1);
y_coord = x_coord;
x_coord(1) = nof_pixels/2;
y_coord(1) = nof_pixels/2;
m = 2;
sidelength = 1;


% make a spiral of coordinates
while m <= spiral_length
      
    % go right
    for n = m:(m+sidelength-1)
        x_coord(n) = x_coord(n-1) + 1;
        y_coord(n) = y_coord(n-1);
    end
    m = m+sidelength;
    
    % go up
    for n = m:(m+sidelength-1)
        x_coord(n) = x_coord(n-1);
        y_coord(n) = y_coord(n-1) + 1;
    end
    m = m+sidelength;
    sidelength = sidelength + 1;
    
    % go left
    for n = m:(m+sidelength-1)
        x_coord(n) = x_coord(n-1) - 1;
        y_coord(n) = y_coord(n-1);
    end
    m = m+sidelength;
    
    % go down
    for n = m:(m+sidelength-1)
        x_coord(n) = x_coord(n-1);
        y_coord(n) = y_coord(n-1) - 1;
    end
    m = m+sidelength;
    sidelength = sidelength + 1;
end

% figure(1)
    % plot(x_coord, y_coord)
    % axis equal
    % grid on

for n = 1:length(primes)
    if primes(n)
        mask(y_coord(n), x_coord(n)) = 1;
    end
end

imagesc(mask)
save('../ulamsspiral_192.mat', 'mask')