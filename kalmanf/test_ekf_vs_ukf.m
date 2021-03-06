%% Clear everything
%clear

%% Initiate KF parameters
n=4;      %number of state
q=0.1;    %std of process 
r=10;    %std of measurement
s.Q = [1^3/3, 0, 1^2/2, 0;  0, 1^3/3, 0, 1^2/2; 1^2/2, 0, 1, 0; 0, 1^2/2, 0, 1]*q; % covariance of process
s.R=r^2*eye(n/2);        % covariance of measurement  
s.sys=@(t)(@(x)[x(1)+ t*x(3); x(2)+t*x(4); x(3); x(4)]);  % nonlinear state equations
s.obs=@(x)[x(1);x(2)];                               % measurement equation
st=[x(2);y(2);x(2)-x(1);y(2)-y(1)];                                % initial state
s.x=st; %initial state          % initial state with noise
s.P = eye(n);                               % initial state covraiance
x_ukf = s.x;
P_ukf = s.P;
ukf_sys = @(x,u)[5*sin(x(2)+x(3))+u(1);2*cos(x(3))+u(2);x(3)+0.1+u(3)];
ukf_obs = @(x,v)[x(1);x(2);x(3)];

N=1019;                                     % total dynamic steps

%% Instantiate UKF and vars to store output
xV_ukf = zeros(n,N);          %estmate        % allocate memory
PV_ukf = zeros(1,N);
%PV_ukf = cell(1,N);    % use to display ellipses 
sV_ukf = zeros(n/2,N);          %actual
zV_ukf = zeros(n/2,N);
eV_ukf = zeros(n,N);
ukf = UKalmanFilter(s, 0.5, 0, 2);

%% Instantiate EKF and vars to store output
xV_ekf = zeros(n,N);          %estmate        % allocate memory
PV_ekf = zeros(1,N);    
%PV_ekf = cell(1,N);     % use to display ellipses 
sV_ekf = zeros(n/2,N);          %actual
zV_ekf = zeros(n/2,N);
eV_ekf = zeros(n,N);
ekf = EKalmanFilter(s);

for k=2:N
    ukf.s.sys = s.sys(1);
    
    %% Get next measurement
    ukf.s.z = [obs_x(k); obs_y(k)];                     % measurments
    ekf.s.z = ukf.s.z;

    %% Store new state and measurement
    sV_ukf(:,k)= [x(k); y(k)];                             % save actual state
    zV_ukf(:,k)  = ukf.s.z;                             % save measurment
    sV_ekf(:,k)= [x(k); y(k)];                             % save actual state
    zV_ekf(:,k)  = ekf.s.z; 

    %% Iterate both filters
    ekf.s.sys = s.sys(1);
    ekf.s = ekf.Iterate(ekf.s);
    %ukf.s.sys = s.sys(N);
    %[x_ukf, P_ukf] = ukf_fl(ukf_sys, ukf_obs, ekf.s.z, x_ukf, P_ukf,  s.Q, s.R);
    ukf.s = ukf.Iterate(ukf.s);            % ekf 

    %% Store estimated state and covariance
    xV_ukf(:,k) = ukf.s.x;%x_ukf;                            % save estimate
    PV_ukf(k)= ukf.s.P(1,1); % P_ukf(1,1) ; 
    %PV_ukf{k}= ukf.s.P;    % Use to store whole covariance matrix
    xV_ekf(:,k) = ekf.s.x;                            % save estimate
    PV_ekf(k) = ekf.s.P(1,1);
    %PV_ekf{k} = ekf.s.P;    % Use to store whole covariance matrix

    %% Compute squared error
    eV_ukf(:,k) = (ukf.s.x - st).*(ukf.s.x - st);
    eV_ekf(:,k) = (ekf.s.x - st).*(ekf.s.x - st);

    %% Generate new state
    %st = ukf.s.sys(st)+q*(-1 + 2*rand(3,1));                % update process 
end

%% Compute & Print RMSE
RMSE_ukf = sqrt(sum(eV_ukf,2)/N)
RMSE_ekf = sqrt(sum(eV_ekf,2)/N)


%% Plot results
figure
for k=1:2                                 % plot results
    subplot(3,1,k)
%     figure
%     hold on
    plot(1:N, sV_ukf(k,:), 'k--', 1:N, xV_ukf(k,:), 'b-',1:N, xV_ekf(k,:), 'g-', 1:N, zV_ukf(k,:), 'r.')
%     for i = 1:N
%         hold on
%         error_ellipse('C', blkdiag(PV_ukf{i}(1,1),1), 'mu', [i, xV_ukf(k,i)], 'style', 'r--')
%         hold on
%         error_ellipse('C', blkdiag(PV_ekf{i}(1,1),1), 'mu', [i, xV_ekf(k,i)], 'style', '--')
%     end
    str = sprintf('EKF vs UKF estimated state X(%d)',k);
    title(str)
    legend('Real', 'UKF', 'EKF', 'Meas');
end


subplot(3,1,3)
plot(1:N, PV_ukf(:,:), 1:N, PV_ekf(:,:))
title(sprintf('EKF vs UKF estimated covariance P(1,1)',k))
legend('UKF', 'EKF');

figure
plot( sV_ukf(1,:), sV_ukf(2,:),xV_ukf(1,:), xV_ukf(2,:), xV_ekf(1,:),xV_ekf(2,:), zV_ukf(1,:), zV_ukf(2,:), 'r.');
title(sprintf('EKF vs UKF estimated covariance P(1,1)',k))
legend('true','UKF', 'EKF', 'meas');

