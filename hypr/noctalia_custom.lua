hl.layer_rule({
	name = "noctalia",
	match = {
		namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
	},
	no_anim = true,
	ignore_alpha = 0.5,
	blur = true,
	blur_popups = true,
})

hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-1", persistent = true })
