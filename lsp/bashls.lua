return {
	cmd = { "bash-language-server", "start" },
	filetypes = { "sh" },
	settings = {
		bashIde = {
			shellcheckArguments = {
				"-e", "SC2034", -- unused variables
				"-e", "SC2086", -- unquoted variables
				"-e", "SC2296",
				"-e", "SC2016",
				"-e", "SC1091",
				"-e", "SC1090",
        "-e", "SC2059"
			},
		},
	},
}
