function [AR_prctile,J_err_prctile] = Torsional_Stiffness(slices,stalknums,numNEPCs,E_ratio)
% FILENAME: Longitudinal_Stiffness.m
% AUTHOR: Michael Ottesen
% DATE: 5/2020
%
% PURPOSE: Calculate longitudinal compression stiffness percent error for
%          ellipse fit and subsequent principal components.
% 
% INPUTS:
%       slices: Row vector of slice locations, relative to the node. This 
%       should be a subset of the input that went into AllTransversePCA.m
%       (as of 1/22/2020, this was
%       [-40 -30 -20 -15 -10 -5 0 5 10 15 20 30 40], so slices could be
%       something like [-20 -10 0 30] if used with AllTransversePCA.m)
%       
%       stalknums: A vector of unique integers from 1 to 980 that determines
%       which stalks to sample from (use randperm(980,K) to choose K
%       unique integers from 1 to 980)       
%
%       numNEPCs: An integer of the desired number of principal components
%       to include in the analysis.
%
%       E_ratio: A number that defines how much greater the rind modulus is
%       compared to the pith modulus. based on other study data, this ratio
%       should be between 20 - 80. For example, if a modulus ratio Er:Ep of
%       20:1 is desired, enter '20'.
%       
% OUTPUTS:
%       AR_prcentile: The values of the key percentiles for the area
%       ratios. These are [5,25,50,75,90]th percentiles. Each row
%       represents a slice distance as specified in the inputs.
%
%       S_err_prctile: The values of the key percentiles for the stiffness
%       errors. The percentiles are also listed as [5,25,50,75,90]th
%       percentiles. Each row represents the ellipse with principal
%       components stiffness error as compared to the real shape.
%
%
% NOTES: 
%       - 
% 
% PSEUDO-CODE:
%   Load AllSlicesPCA data.
%   Begin 'for' loop to run for each slice location.
%        Begin 'for' loop to run for number of cross sections.
%            
%   Create box plot of percent error for each shape.
%         
% 
% VERSION HISTORY:
% V1 - 
% V2 - 
% V3 - 
%
% -------------------------------------------------------------------------


% Load data from AllTransversePCA.mat
load('AllSlicesPCA.mat')

% Intitialize the problem stalk indices
problem_slice_stalk = [];

% Define slice number to keep trak of number of iterations (slice dists as
% an iteration number)
slicenum = 0;
CSnum = 0;
dr = 0.1;

% Iterate through slices (determine group number here)
for slice = slices
    slicenum = slicenum + 1;
    
    % Determine the indices in the data where the slice location lives
    sliceidx = find(slice_dists == slice);
    
    % slice_startstop is a variable that loads from AllSlicesPCA.mat.
    % startidx is the index 
    startidx = slice_startstop(sliceidx,2);
    
    % For each slice position, iterate through stalknums
    for stalk = stalknums
        CSnum = CSnum + 1;
        % Get the actual index of the chosen data and create a Python script for
        % that case, numbering by group
        indices = cell2mat(adj_indices(sliceidx,1));
        stalkidx = find(indices == stalk);
        
        if isempty(stalkidx)
            problem_slice_stalk = [problem_slice_stalk; slice, stalk];
            continue
        end
        
        % adj_ind is the row index where the specific cross-section is
        % within the "ALL" arrays
        adj_ind = startidx + stalkidx - 1;
        
        % Real cross section (case 0)
        case_num = 0; % increment this for each case within each cross section
        
        % Define theta for calculating moment area of inertia (all are
        % the same)
        theta = ALL_ELLIPSE_T(1,:);
        
        % Track the indice number in the first column
        Jp(CSnum,1,slicenum) = adj_ind;
        Jr(CSnum,1,slicenum) = adj_ind;
        
        % Calculate pith and rind polar inertias for true cross section
        Jp(CSnum,2,slicenum) = Polar_Inertia(theta,ALL_R_int(adj_ind,:),dr);
        Jr(CSnum,2,slicenum) = Polar_Inertia(theta,ALL_R_ext(adj_ind,:),dr) - Jp(CSnum,2,slicenum);
        
%         polarplot(theta,ALL_R_int(adj_ind,:),theta,ALL_R_ext(adj_ind,:))
        
        
         % Calculate pith and rind polar inertias for ellipse cross section
        Jp(CSnum,3,slicenum) = Polar_Inertia(theta,ALL_ELLIPSE_R_int(adj_ind,:),dr);
        Jr(CSnum,3,slicenum) = Polar_Inertia(theta,ALL_ELLIPSE_R_ext(adj_ind,:),dr) - Jp(CSnum,3,slicenum);
        
%         polarplot(theta,ALL_ELLIPSE_R_int(adj_ind,:),theta,ALL_ELLIPSE_R_ext(adj_ind,:))
        
        
        % Combined PC cases
        for j = 1:numNEPCs
            case_num = case_num + 1;

            % Calculate the cases with PCs cumulatively added into the
            % ellipse fit
            NEPC_int = zeros(1,size(ext_rhoPCAs,1));
            NEPC_ext = zeros(1,size(ext_rhoPCAs,1));
            
            for k = 1:j
                % Add all NEPCs up to the current NEPC to the ellipse in polar coordinates
                NEPC_ext = NEPC_ext + ext_rhocoeffs(adj_ind,k)*ext_rhoPCAs(:,k)';
                NEPC_int = NEPC_int + int_rhocoeffs(adj_ind,k)*int_rhoPCAs(:,k)';
            end
            
            % Construct the new exterior and interior boundaries
            Rnew_ext = ALL_ELLIPSE_R_ext(adj_ind,:) - NEPC_ext;
            Rnew_int = ALL_ELLIPSE_R_int(adj_ind,:) - NEPC_int;
            
            % Calculate rind and pith area for adjusted ellipse shape
            Jp(CSnum,j+3,slicenum) = Polar_Inertia(theta,Rnew_int,dr);
            Jr(CSnum,j+3,slicenum) = Polar_Inertia(theta,Rnew_ext,dr) - Jp(CSnum,j+3,slicenum);
            
%             polarplot(theta,Rnew_int,theta,Rnew_ext)
            
            
        end
    end
end


% Calculate percent error 
% Find ratio value for real shape and varried ellipse
ref = E_ratio*Jr(:,2,:) + 1*Jp(:,2,:);
VE = E_ratio*Jr(:,3:numNEPCs+3,:) + 1*Jp(:,3:numNEPCs+3,:);

% Get percent error for each varried ellipse compared to real shape
for i = 1:numNEPCs+1
    J_err(:,i,:) = ((VE(:,i,:) - ref(:,1,:))./ref(:,1,:))*100;
    J_err_prctile_i(i,:,:) = prctile(J_err(:,i,:),[5,25,50,75,95]);
    for j = 1:5
       J_err_prctile(i,j) = mean(J_err_prctile_i(i,j,:)); 
    end
end


% Create labels according to the number of principal components used in
% the study (cumulative cases followed by remaining individual cases)
all_labels = strings(1,(1+numNEPCs));
all_labels(1,1:2) = ["Ellipse","Ellipse + PC 1"];
for i = 2:numNEPCs
    addlabel = "Ellipse + PCs 1-" + num2str(i);
    all_labels(1,i+1) = addlabel;
end

% Combine all percent error data into one matrix for box plotting
J_err_plot = J_err(:,:,1);
for i = 1:length(slices)-1
J_err_plot = [J_err_plot;J_err(:,:,i+1)];
end

% Grab upper and lower limits by using 5th and 95th percentile data
uplimrow = J_err_prctile(:,5)';
lolimrow = J_err_prctile(:,1)';

% Add a buffer between the calculated outer reach of the whiskers and the
% edge of the plot. Round to the nearest integer for a nice y label.
buffer = 3;
uplim = max(uplimrow) + buffer;
lolim = min(lolimrow) - buffer;
uplim = round(uplim);
lolim = round(lolim);

% Create box plot 
% Include significance notches on boxes
% supress outliers
figure(2)
boxplot(J_err_plot,all_labels,'notch','on','symbol','')
ylim([lolim,uplim]);
set(gca,'YTick',lolim:0.5:uplim,'XTickLabelRotation',-30);
ytickformat('percentage');
ylabel('Error');
title('Torsional Stiffness')
hold on
yline(0);
hold off

 
end