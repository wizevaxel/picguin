--!strict
--!optimize 2

local types = require("@self/types")
local decode = require("@self/decode")
local encode = require("@self/encode")

export type ColorSpace = types.ColorSpace
export type CriticalChunk = types.CriticalChunk
export type AncillaryChunk = types.AncillaryChunk
export type Chunk = types.Chunk

export type DecodeErrorCode = decode.DecodeErrorCode
export type DecodeError = decode.DecodeError
export type CelErrorCode = decode.CelErrorCode
export type CelError = decode.CelError
export type Parsed = decode.Parsed
export type Cel = decode.Cel
export type BitmapRegion = decode.BitmapRegion
export type DecodeOptions = decode.DecodeOptions

return table.freeze {
	version = "0.1.1",
	decode = decode,
	encode = encode,
}
