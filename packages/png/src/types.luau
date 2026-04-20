--!strict

local core = require("../roblox_packages/core")

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
	use: {AncillaryChunk}?,
}

export type Decoder = core.Decoder<{
	headers: {},
}>

export type AncillaryChunk =
	| "tRNS"
	| "gAMA"
	| "cHRM"
	| "sRGB"
	| "iCCP"
	| "pHYs"
	| "bKGD"
	| "tEXt"
	| "iTXt"
	| "zTXt"
	| "tIME"
	| "eXIf"

return nil
