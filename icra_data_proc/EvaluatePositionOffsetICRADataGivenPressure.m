% ratio_train is the ratio of the entire dataset for training. 
% ratio_validation is the ratio among training dataset for validation
% search over parameters.
function [record_all, record_ls_training] = EvaluatePositionOffsetICRADataGivenPressure(file_name, ls_type, mu, ratio_train, ratio_validation, support_pts, pressure_weights)
p = gcp;
if (isempty(p))
    num_physical_cores = feature('numcores');
    parpool(num_physical_cores);
end
trans = [50;50;0];
% Local frame transformation w.r.t mocap local frame (lower left corner).
H_tf = [eye(3,3), trans;
      0,0,0,1];
% Tool transform.
R_tool = [sqrt(2)/2, sqrt(2)/2;
          sqrt(2)/2, -sqrt(2)/2]';
% Parameters for trianglular block.         
le = 0.15;
% Formula for computing rho using wolfram alpha:
% sqrt((\int_{0}^{0.15}(\int_{0}^{0.15-x}(x^2+y^2)dy)dx - 0.5*0.15*0.15*0.05^2)/(0.5*0.15*0.15));
% mass is 0.5*0.15*0.15 assuming density equals 1 and then use parallel
% axis theorem. 
Tri_pho = le/3 * sqrt(2);
unit_scale = 1000;
% Construct triangular push object.
shape_info.shape_id = 'tri';
shape_info.shape_type = 'polygon';

% lower left, upper left, lower right. 
shape_info.shape_vertices = [-le/3, -le/3, le*2/3;
                             -le/3, le*2/3, -le/3];
shape_info.pho = Tri_pho;
% Note that the object 2d pose is already at the center of the object.
[record_log] = ExtractFromLog(file_name, Tri_pho, R_tool, H_tf, unit_scale);
                         
tip_radius = 0.001;
hand_single_finger = ConstructSingleRoundFingerHand(tip_radius);


%Split train_all and test trials. 
num_trials = size(record_log.push_wrenches, 1);
index_perm = randperm(num_trials);
split_ind = ceil(num_trials * ratio_train);
index_train = index_perm(1:split_ind);
index_test = index_perm(split_ind + 1:end);

pushobj = PushedObject(support_pts, pressure_weights, shape_info, ls_type);
pushobj.FitLS(ls_type, 400, 0.1);
ls_coeffs = pushobj.ls_coeffs;

%devs = zeros(length(index_test), 1);
record_all = cell(length(index_test), 1);
record_ls_training.ls_coeffs = ls_coeffs;
record_ls_training.ls_type = ls_type;


%mu_trials = [mu-0.075;mu-0.05;mu-0.025;mu;mu+0.025;mu+0.05;mu+0.075];
%mu_trials = [mu-0.1;mu - 0.05; mu; mu + 0.05; mu + 0.1; ];
mu_trials = [mu-0.1; mu-0.05;mu; mu + 0.05; mu + 0.1];
%mu_trials = [mu];
mu_best = 0;
val_best = 1e+3;
ct_mu = 1;
while ct_mu <= length(mu_trials)
    devs = zeros(length(index_train), 1);
    mu_test = mu_trials(ct_mu);
    parfor i = 1:1:length(index_train)
        ind_trial_train = index_train(i);
        hand_poses = record_log.robot_2d_pos_full{ind_trial_train}';
        hand_traj_opts = [];
        hand_traj_opts.q = hand_poses;
        hand_traj_opts.t = linspace(0,1, size(hand_poses, 2));
        hand_traj_opts.interp_mode = 'spline';
        hand_traj = HandTraj(hand_traj_opts);

        pushobj = PushedObject([], [], shape_info, ls_type, ls_coeffs);
        object_poses = record_log.obj_2d_traj{ind_trial_train}';
        pushobj.pose = object_poses(:,1);
        sim_inst = ForwardSimulationCombinedState(pushobj, hand_traj, hand_single_finger, mu_test);
        [sim_results] = sim_inst.RollOut();

        weight_angle_to_disp = 1;
        alpha = mod(sim_results.obj_configs(3,end) + 10 * pi, 2*pi);
        beta = mod(object_poses(3, end) + 10 *pi, 2*pi);
        devs(i) =  norm(sim_results.obj_configs(1:2,end) - object_poses(1:2, end)) + ...
                   weight_angle_to_disp * pushobj.pho * abs(compute_angle_diff(alpha, beta));
    end
    %mu_test, mean(devs)
    if (mean(devs) < val_best)
        val_best = mean(devs);
        mu_best = mu_test;
    end
    ct_mu = ct_mu + 1;
end
mu_best

parfor i = 1:1:length(index_test) 
ind_trial_test = index_test(i);
% Specify finger trajectory.
%hand_poses = record_log.robot_2d_pos{ind_trial_test}';
hand_poses = record_log.robot_2d_pos_full{ind_trial_test}';
hand_traj_opts = [];
hand_traj_opts.q = hand_poses;
hand_traj_opts.t = linspace(0,1, size(hand_poses, 2));
hand_traj_opts.interp_mode = 'spline';
hand_traj = HandTraj(hand_traj_opts);

pushobj = PushedObject([], [], shape_info, ls_type, ls_coeffs);
object_poses = record_log.obj_2d_traj{ind_trial_test}';
pushobj.pose = object_poses(:,1);
sim_inst = ForwardSimulationCombinedState(pushobj, hand_traj, hand_single_finger, mu_best);
[sim_results] = sim_inst.RollOut();

%weight_angle_to_disp = 1;
%alpha = mod(sim_results.obj_configs(3,end) + 10 * pi, 2*pi);
%beta = mod(object_poses(3, end) + 10 *pi, 2*pi);
%norm(object_poses(1:2, end) - object_poses(1:2, 1))
%fprintf('displacement %f, angle %f\n', norm(sim_results.obj_configs(1:2,end) - object_poses(1:2, end)), abs(compute_angle_diff(alpha, beta)));
%devs(i) =  norm(sim_results.obj_configs(1:2,end) - object_poses(1:2, end)) + ...
%       weight_angle_to_disp * pushobj.pho * abs(compute_angle_diff(alpha, beta));
record_all{i}.init_pose_gt = object_poses(:,1);
record_all{i}.final_pose_gt = object_poses(:,end);
record_all{i}.final_pose_sim = sim_results.obj_configs(:, end);
end
%mean(devs)
end