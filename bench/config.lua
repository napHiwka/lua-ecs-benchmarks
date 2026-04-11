return {
	seed = 1337,

	execution = {
		runsPerAdapter = 5,
		includeStressScenarios = true,
	},

	garbageCollection = {
		collectBeforeScenario = true,
		collectAfterScenario = true,
	},

	dataset = {
		entitiesPerRun = 500,
		componentsPerWorld = 10,
		baseComponentFill = 0.65,
		primaryQueryComponentFill = 0.45,
		hotComponentFill = 1.0,
	},

	queryWorkloads = {
		queryIterations = 500,
		wideQueryWidth = 9,
		randomReadCount = 10000,
		multiQueryCount = 24,
		workFrameCount = 40,
		writesPerWorkFrame = 200,
	},

	mutationWorkloads = {
		writesPerPhase = 5000,
		structuralChangesPerPhase = 5000,
	},

	stress = {
		frameCount = 50,
		writePasses = 50,
		structuralPasses = 50,
	},
}
