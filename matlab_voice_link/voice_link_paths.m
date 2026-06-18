function paths = voice_link_paths()
%VOICE_LINK_PATHS Shared filesystem paths for the standalone open-source toolkit.

thisDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(thisDir);

paths = struct();
paths.rootDir = rootDir;
paths.outputDir = fullfile(rootDir, "outputs", "data", "reference_cosim");
paths.figureDir = fullfile(paths.outputDir, "figures");
paths.voice_linkPlotDir = fullfile(rootDir, "outputs", "figures", "screening_report");
paths.pythonGeoSatphoneDir = fullfile(rootDir, "outputs", "data", "voice_link");
paths.pythonOutageCapacityDir = fullfile(rootDir, "outputs", "data", "outage_capacity");
end
