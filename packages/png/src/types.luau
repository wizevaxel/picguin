--!strict

local core = require("../roblox_packages/core")

export type ErrorCode =
	| core.ErrorCode
	| "invalid_signature"
	| "invalid_crc"

export type DecodeError = core.DecodeError<ErrorCode>

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
