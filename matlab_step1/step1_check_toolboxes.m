function status = step1_check_toolboxes(cfg)
%STEP1_CHECK_TOOLBOXES Check toolbox availability for the Step 1 upgrade.

if nargin < 1 || isempty(cfg)
    cfg = step1_params();
end

status = struct();
status.matlab_version = version();
status.has_simulink = step1_license_test('Simulink') && exist('simulink', 'file') == 2;
status.has_comm_toolbox = step1_license_test('Communication_Toolbox') || step1_license_test('Communications_Toolbox');
status.has_dsp_toolbox = step1_license_test('Signal_Blocks') || step1_license_test('DSP_System_Toolbox');
status.has_satcom_toolbox = step1_license_test('Satcom_Toolbox') || exist('satelliteScenario', 'file') == 2;
status.has_parallel_toolbox = step1_license_test('Distrib_Computing_Toolbox');

commObjects = {
    'comm.ConvolutionalEncoder'
    'comm.ViterbiDecoder'
    'comm.PSKModulator'
    'comm.PSKDemodulator'
    'comm.AWGNChannel'
    'comm.RicianChannel'
    'comm.RayleighChannel'
    'comm.ErrorRate'
};
status.comm_objects = table();
for i = 1:numel(commObjects)
    objectName = commObjects{i};
    available = exist(objectName, 'class') == 8;
    status.comm_objects = [status.comm_objects; table(string(objectName), available, ...
        'VariableNames', {'object_name', 'available'})];
end

if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
writetable(status.comm_objects, fullfile(cfg.outputDir, 'toolbox_comm_objects.csv'));

fid = fopen(fullfile(cfg.outputDir, 'toolbox_status.json'), 'w');
fprintf(fid, '{\n');
fprintf(fid, '  "matlab_version": "%s",\n', status.matlab_version);
fprintf(fid, '  "has_simulink": %s,\n', lower(string(status.has_simulink)));
fprintf(fid, '  "has_comm_toolbox": %s,\n', lower(string(status.has_comm_toolbox)));
fprintf(fid, '  "has_dsp_toolbox": %s,\n', lower(string(status.has_dsp_toolbox)));
fprintf(fid, '  "has_satcom_toolbox": %s,\n', lower(string(status.has_satcom_toolbox)));
fprintf(fid, '  "has_parallel_toolbox": %s\n', lower(string(status.has_parallel_toolbox)));
fprintf(fid, '}\n');
fclose(fid);
end

function tf = step1_license_test(featureName)
try
    tf = license('test', featureName);
catch
    tf = false;
end
end
