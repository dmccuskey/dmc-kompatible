# dmc-kompatible

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-kompatible"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-kompatible",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_kompatible.lua",
		],
		"requires": [
			"dmc-corona-boot"
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}


register( "dmc-kompatible", module_config )
