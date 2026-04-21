--!strict

local core = require("../roblox_packages/core")

export type ErrorCode =
	| core.ErrorCode
	| "invalid_crc"

export type DecodeContext = {
	
}

export type DecodeOptions = {
	crc: ("all" | "critical" | "none")?,
	use: {AncillaryChunk}?,
}

export type Decoded = core.Decoded<{
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
