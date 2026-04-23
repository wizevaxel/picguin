--!strict

local core = require("../roblox_packages/core")

export type ErrorCode =
	| core.ErrorCode
	| "invalid_signature"
	| "invalid_crc"
	| "invalid_length"
	| "invalid_header"
	| "invalid_chunk"
	| "missing_iend"

export type DecodeError = core.DecodeError<ErrorCode>

export type ColorType =
	| "truecolor"
	| "grayscale"
	| "indexed"

export type Chunk = CriticalChunk | AncillaryChunk

export type CriticalChunk =
	| "IHDR"
	| "IDAT"
	| "PLTE"
	| "IEND"

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
