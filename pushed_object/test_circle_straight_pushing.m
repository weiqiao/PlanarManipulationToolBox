addpath('~/Downloads/cvx/');
cvx_startup;
shape_info.shape_id = 'circle1';
shape_info.shape_type = 'circle';
shape_info.shape_parameters.radius = 0.02;
shape_info.pho = shape_info.shape_parameters.radius;

options_support_pts.mode = 'circle';
options_support_pts.range = shape_info.shape_parameters.radius;

num_supports_pts = 100; 
support_pts = GridSupportPoint(num_supports_pts, options_support_pts); % N*2.

options_pressure.mode = 'uniform';
pressure_weights = AssignPressure(support_pts, options_pressure);


%pushobj = PushedObject(support_pts', pressure_weights, shape_info, 'quadratic')
% Set the circle at the point of origin.
pushobj.pose = [0;0;0];

const_v_magnitude = 0.01;
const_v = const_v_magnitude * [0;-1];

const_mu = 0.2;
finger_radius = 0.005;
init_finger_pos = [-shape_info.shape_parameters.radius/2; shape_info.shape_parameters.radius*1.25; 0];

total_time = 2;
total_num_t = 50;

t = linspace(0, total_time, total_num_t);
figure;
for i = 1:1:total_num_t-1
    dt = t(i+1) - t(i);
    pt_finger_center = init_finger_pos(1:2) + t(i) * const_v;
    %pushobj.pose
    drawCircle(pt_finger_center(1), pt_finger_center(2), finger_radius, 'color', 'k');
    hold on;
    drawCircle(pushobj.pose(1), pushobj.pose(2), shape_info.shape_parameters.radius, 'color', 'r');
    twist = [const_v;0];
    [flag_contact, pt_contact, vel_contact, outward_normal_contact] = ...
          pushobj.GetRoundFingerContactInfo(pt_finger_center, finger_radius, twist);
    if (flag_contact)
        [twist_local, wrench_load_local, contact_mode] = ...
            pushobj.ComputeVelGivenPointRoundFingerPush(pt_contact, vel_contact, outward_normal_contact, const_mu)
        % Convert local twist to global frame.
        theta = pushobj.pose(3);
        R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
        pushobj.pose(1:2) = pushobj.pose(1:2) + R * twist_local(1:2) * dt;
        pushobj.pose(3) = pushobj.pose(3) + twist_local(3) * dt;
        %Adg = [R, [pushobj.pose(2);-pushobj.pose(1)];0,0,1];
        %twist_global = Adg * twist_local
        %pushobj.pose = pushobj.pose + twist_global * (t(i+1) - t(i))  
    end

    
end
axis equal;
