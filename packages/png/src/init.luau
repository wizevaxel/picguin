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
export type ReadErrorCode = decode.ReadErrorCode
export type ReadError = decode.ReadError
export type Parsed = decode.Parsed
export type Cel = decode.Cel
export type BitmapRegion = decode.BitmapRegion
export type DecodeOptions = decode.DecodeOptions

return table.freeze {
	decode = decode,
	encode = encode,
}
