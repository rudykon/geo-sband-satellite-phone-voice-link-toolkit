function paths = voice_link_paths()
%VOICE_LINK_PATHS Shared filesystem paths for the standalone open-source toolkit.

thisDir = fileparts(mfilename("fullpath"));
rootDir = fileparts(thisDir);

paths = struct();
paths.rootDir = rootDir;
paths.outputDir = fullfile(rootDir, "outputs", "matlab_voice_link");
paths.figureDir = fullfile(paths.outputDir, "figures");
paths.voice_linkPlotDir = fullfile(rootDir, "outputs", "voice_link_screening", "plots");
paths.pythonGeoSatphoneDir = fullfile(rootDir, "outputs", "geo_satphone");
paths.pythonOutageCapacityDir = fullfile(rootDir, "outputs", "outage_capacity");
end
