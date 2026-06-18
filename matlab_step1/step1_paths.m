function paths = step1_paths()
%STEP1_PATHS Shared filesystem paths for the standalone open-source toolkit.

thisDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(thisDir);

paths = struct();
paths.rootDir = rootDir;
paths.outputDir = fullfile(rootDir, "outputs", "matlab_step1");
paths.figureDir = fullfile(paths.outputDir, "figures");
paths.step1PlotDir = fullfile(rootDir, "outputs", "step1_link", "plots");
paths.pythonGeoSatphoneDir = fullfile(rootDir, "outputs", "geo_satphone");
paths.pythonOutageCapacityDir = fullfile(rootDir, "outputs", "outage_capacity");
end
