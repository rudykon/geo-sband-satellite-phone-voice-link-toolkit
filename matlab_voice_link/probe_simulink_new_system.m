disp('probe new_system');
modelName = 'probe_minimal_simulink_model';
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
add_block('simulink/Sources/Constant', [modelName '/constant'], 'Value', '42');
add_block('simulink/Sinks/To Workspace', [modelName '/to_workspace'], ...
    'VariableName', 'probe_out', 'SaveFormat', 'Array');
add_line(modelName, 'constant/1', 'to_workspace/1');
sim(modelName, 'StopTime', '1');
save_system(modelName, fullfile(pwd, [modelName '.slx']));
close_system(modelName, 0);
disp('done');
