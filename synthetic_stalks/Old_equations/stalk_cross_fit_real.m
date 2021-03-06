function [xopt, fopt, exitflag, output] = stalk_cross_fit_real(xreal,yreal)
    % Using optimization routine (fmincon) to get the best fit of the
    % synthetic stalk equations to an example shape
    
%     load XYryan.mat ext_xDCSR ext_yDCSR
%     numsection = 1;
%     
%     xreal = ext_xDCSR(1,:,numsection);
%     yreal = ext_yDCSR(1,:,numsection);
    
    % ------------Starting point and bounds------------
    %var= dmaj  dmin  ndepth  nwidth  nloc    rotate_angle  xshift  yshift xaAmp  xaSym  yaAmp  yaSym % Design variables
    x0 = [200,  150,  15,     1,      pi,     0,            0,      0,     0,     0,     0,     0];      % Starting point
    ub = [300,  300,  30,     5,      3*pi/2, 3*pi/2,       300,    300,   1,     pi,    1      pi];      % Upper bound
    lb = [100,  100,  10,     0.05,   pi/2,   -3*pi/2,      -300,   -300,  -1,    -pi,   -1,    -pi];      % Lower bound

    % ------------Linear constraints------------
    A = [];
    b = [];
    Aeq = [];
    beq = [];

    % ------------Objective and Non-linear Constraints------------
    function [f, c, ceq] = objcon(x)
        
        % Design variables
        dmaj =  x(1);
        dmin =  x(2);
        ndepth =  x(3);
        nwidth = x(4);
        nloc = x(5);
        rotate_angle = x(6);
        xshift = x(7);
        yshift = x(8);
        xaAmp = x(9);
        xaSym = x(10);
        yaAmp = x(11);
        yaSym = x(12);
        
        
        % Other analysis variables
        N = length(xreal);
        theta = linspace(0,2*pi,N);
        phi = nloc - pi;
        
        % Analysis functions
        xasymmetry = xaAmp*sin(theta - xaSym);
        yasymmetry = yaAmp*sin(theta - yaSym);
        xnotch = notch_fn(N,ndepth,nwidth,nloc,theta);
        ynotch = zeros(1,N);
        [xnotch_rot,ynotch_rot] = rotate(xnotch,ynotch,phi,N);
        
        xmain = xpts(N,theta,dmaj,xasymmetry);
        ymain = ypts(N,theta,dmin,yasymmetry);
        
        x = xmain + xnotch_rot;
        y = ymain + ynotch_rot;
        [x,y] = rotate(x,y,rotate_angle,N);
        xsynth = xshift + x;
        ysynth = yshift + y;
        
        
        % Objective function
        f = getfit(xreal,xsynth,yreal,ysynth); % Minimize the fit metric
        
        % Inequality constraints
        c = dmin - dmaj;
        
        % Equality constraints
        ceq = [];
        
    end

    % ------------Call fmincon------------
    options = optimoptions(@fmincon, 'display', 'iter-detailed');
    [xopt, fopt, exitflag, output] = fmincon(@obj, x0, A, b, Aeq, beq, lb, ub, @con, options);
    xopt
    fopt
    [~,c,~] = objcon(xopt);
    c
    
    % ------------Separate obj/con (do not change)------------
    function [f] = obj(x)
            [f, ~, ~] = objcon(x);
    end
    function [c, ceq] = con(x)
            [~, c, ceq] = objcon(x);
    end

    % ------------Stalk geometry functions---------------
    function [x] = xpts(N,theta,dmaj,asymmetry)
        x = zeros(1,N);
        for i = 1:N
            x(i) = (dmaj/2)*(cos(theta(i))) + asymmetry(i);
        end
    end

    function [y] = ypts(N,theta,dmin,asymmetry)
        y = zeros(1,N);
        for i = 1:N
            y(i) = (dmin/2)*(sin(theta(i))) + asymmetry(i);
        end
    end

    function [notch] = notch_fn(N,ndepth,nwidth,nloc,theta)
        notch = zeros(1,N);
        for i = 1:N
            notch(i) = ndepth/cosh((10/nwidth)*(theta(i)-nloc))^2;
        end
    end

    function [asymmetry] = Asymmetry(aAmplim,theta)
    %     asymmetry = zeros(1,N);
        aAmp = unifrnd(-aAmplim,aAmplim);
        aSym = unifrnd(-pi,pi);
        asymmetry = aAmp*sin(theta - aSym);
    end

    function [xrotate,yrotate] = rotate(x,y,psi,N)
        xrotate = zeros(1,N);
        yrotate = zeros(1,N);

        R = [cos(psi) -sin(psi); sin(psi) cos(psi)];

        for i = 1:N
            temp = [x(i);y(i)];
            temp = R*temp;
            xrotate(i) = temp(1);
            yrotate(i) = temp(2);
        end
    end
    
    
    function [fitmetric] = getfit(xreal,xsynth,yreal,ysynth,zreal,zsynth)
        % Get the overall fit of a synthetic shape against a real shape, in a
        % single value similar to a standard deviation

        N = length(xreal);

        if nargin == 2
            yreal = zeros(N);
            ysynth = zeros(N);
            zreal = zeros(N);
            zsynth = zeros(N);

        elseif nargin == 4
            zreal = zeros(N);
            zsynth = zeros(N);

        elseif mod(nargin,2) == 1
            error('Odd number of arguments');
        end

        sum = 0;

        for i = 1:N
            xsq = (xsynth(i) - xreal(i))^2;
            ysq = (ysynth(i) - yreal(i))^2;
            zsq = (zsynth(i) - zreal(i))^2;
            sum = sum + xsq + ysq + zsq;
        end

        fitmetric = sqrt(sum/N);

    end



end
