%RUN_STEP1_MATLAB_DESKTOP_JOB Run Step 1 validation from MATLAB Desktop.
%
% This wrapper is intended for GUI/desktop launches with matlab -r. It keeps a
% diary log and writes a small status file so external automation can tell
% whether the full MATLAB/Simulink workflow completed.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = step1_params();
if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end

logPath = fullfile(cfg.outputDir, 'matlab_desktop_gui_run.log');
statusPath = fullfile(cfg.outputDir, 'desktop_gui_status.txt');

if exist(logPath, 'file'), delete(logPath); end
if exist(statusPath, 'file'), delete(statusPath); end

diary(logPath);
fprintf('Step 1 MATLAB Desktop GUI job started: %s\n', datestr(now, 31));

try
    run_step1_matlab_simulink;
    fid = fopen(statusPath, 'w');
    fprintf(fid, 'completed\n%s\n', datestr(now, 31));
    fclose(fid);
    fprintf('Step 1 MATLAB Desktop GUI job completed: %s\n', datestr(now, 31));
catch ME
    fprintf(2, '\nStep 1 MATLAB Desktop GUI job failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  at %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    fid = fopen(statusPath, 'w');
    fprintf(fid, 'failed\n%s\n%s\n', datestr(now, 31), ME.message);
    fclose(fid);
end

diary off;
