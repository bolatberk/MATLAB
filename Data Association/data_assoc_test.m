% Number of Target Tracks
TrackNum = 2;
DataList = gen_obs_cluttered_multi(TrackNum, x_true, y_true);

% Initiate KF parameters
n=4;      %number of state
q=0.01;    %std of process 
r=0.4;    %std of measurement
s.Q=[1^3/3, 0, 1^2/2, 0;  0, 1^3/3, 0, 1^2/2; 1^2/2, 0, 1, 0; 0, 1^2/2, 0, 1]*10*q^2; % covariance of process
s.R=r^2*eye(n/2);        % covariance of measurement  
s.sys=(@(x)[x(1)+ x(3); x(2)+x(4); x(3); x(4)]);  % assuming measurements arrive 1 per sec
s.obs=@(x)[x(1);x(2)];                               % measurement equation
st=[x_true(1,1);y_true(1,1)];                                % initial state
s.x_init = [];
s.P_init = [];

% PF parameters
% Process equation x[k] = sys(k, x[k-1], u[k]);
sys_cch = @(k, xkm1, uk) [xkm1(1)+1*xkm1(3)*cos(xkm1(4)); xkm1(2)+1*xkm1(3)*sin(xkm1(4)); xkm1(3)+ uk(3); xkm1(4) + uk(4)];

% Observation equation y[k] = obs(k, x[k], v[k]);
obs = @(k, xk, vk) [xk(1)+vk(1); xk(2)+vk(2)];                  % (returns column vector)    

% PDF of process and observation noise generator function
nu = 4;                                           % size of the vector of process noise
sigma_u = q;
cov_u = [Dt^3/3, 0, Dt^2/2, 0;  0, Dt^3/3, 0, Dt^2/2; Dt^2/2, 0, Dt, 0; 0, Dt^2/2, 0, 1]*sigma_u^2;
gen_sys_noise_cch = @(u) mvnrnd(zeros(1, nu), diag([0,0,0.01^2,0.3^2])); 

nv = 2;                                           % size of the vector of observation noise
sigma_v = r;
cov_v = sigma_v^2*eye(nv);
p_obs_noise   = @(v) mvnpdf(v, zeros(1, nv), cov_v);
gen_obs_noise = @(v) mvnrnd(zeros(1, nv), cov_v);         % sample from p_obs_noise (returns column vector)

% Initial PDF
gen_x0_cch = @(x) mvnrnd([obs_x(1,1); obs_y(1,1); 0; 0],diag([sigma_u^2, sigma_u^2, (Vmax^2/3), 0]));               % sample from p_x0 (returns column vector)              % sample from p_x0 (returns column vector)

% Observation likelihood PDF p(y[k] | x[k])
% (under the suposition of additive process noise)
p_yk_given_xk = @(k, yk, xk) p_obs_noise((yk - obs(k, xk, zeros(1, nv)))');


for i = 1:TrackNum
    s.x_init(:,i)=[DataList(1,i,2); DataList(2,i,2); DataList(1,i,2)-DataList(1,i,1); DataList(2,i,2)-DataList(2,i,1)]; %initial state
end
s.P_init = [q^2, 0, q^2, 0;
            0, q^2, 0, q^2;
            q^2, 0, 2*q^2, 0;
            0, q^2, 0, 2*q^2];                               % initial state covraiance

% Process and Observation handles and covariances
TrackObj.sys          = s.sys;
TrackObj.obs          = s.obs;
TrackObj.Q          = s.Q;
TrackObj.R          = s.R;

% initial covariance assumed same for all tracks
TrackObj.P          = s.P_init;

N=size(obs_x1,1) ;                                    % total dynamic steps

% Instantiate EKF and vars to store output
xV_ekf = zeros(n,N);          %estmate        % allocate memory
xV_ekf(:,1) = s.x_init(:,1);
PV_ekf = zeros(1,N);    
%PV_ekf = cell(1,N);     % use to display ellipses 
sV_ekf = zeros(n/2,N);          %actual
sV_ekf(:,1) = st;
zV_ekf = zeros(n/2,N);
eV_ekf = zeros(n/2,N);

% Initiate Tracklist
TrackList = [];
for i=1:TrackNum,
    
    TrackObj.x          = s.x_init(:,i)
    TrackList{i}.TrackObj = TrackObj;
    %TrackList{i}.TrackObj.x(ObservInd) = CenterData(:,i);

end;

ekf = EKalmanFilter(TrackObj);

img = imread('maze.png');
 
% set the range of the axes
% The image will be stretched to this.
min_x = 0;
max_x = 10;
min_y = 0;
max_y = 10;
 
% make data to plot - just a line.
x = min_x:max_x;
y = (6/8)*x;

figure
for i=2:N
    clf; % Flip the image upside down before showing it
    imagesc([min_x max_x], [min_y max_y], flipud(img));

    % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.

    hold on;
    i
    [TrackList, Validation_matrix] = Observation_Association(TrackList, DataList(:,:,i), ekf);
    TrackList = PDAF_Update(TrackList, DataList(:,:,i), Validation_matrix);
    
    xV_ekf(:,i) = TrackList{1,1}.TrackObj.x;
    st = [x_true(i,1); y_true(i,1)];
    sV_ekf(:,i)= st;
    % Compute squared error
    eV_ekf(:,i) = (TrackList{1,1}.TrackObj.x(1:2,1) - st).*(TrackList{1,1}.TrackObj.x(1:2,1) - st);
    
    h2 = plot(sV_ekf(1,1:i),sV_ekf(2,1:i),'b.-','LineWidth',1);
    h2 = plot(sV_ekf(1,i),sV_ekf(2,i),'bo','MarkerSize', 20);
    h2 = plot(DataList(1,:,i),DataList(2,:,i),'k*','MarkerSize', 20);
    h4 = plot(xV_ekf(1,1:i),xV_ekf(2,1:i),'r.-','LineWidth',1);
    h4 = plot(xV_ekf(1,i),xV_ekf(2,i),'ro','MarkerSize', 20);
    % set the y-axis back to normal.
    set(gca,'ydir','normal');
    axis([0 10 0 10])
    pause(0.1) 

end

% Compute & Print RMSE
RMSE_ekf = sqrt(sum(eV_ekf,2)/N)

figure
hold on;
h2 = plot(sV_ekf(1,1:N),sV_ekf(2,1:N),'b.-','LineWidth',1);
h4 = plot(xV_ekf(1,1:N),xV_ekf(2,1:N),'r.-','LineWidth',1);
