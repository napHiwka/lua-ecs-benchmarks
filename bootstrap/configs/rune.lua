return {
	entry = "ecs",
	src = "./rune",
	out = "../../../bench/libraries/rune/init.lua",
	name = "rune",
	extra = {
		"utils",
	},
	strip = "all",
	resolve = true,
	compact = true,
	debug = true,
	verify = true,
}
