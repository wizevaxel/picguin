--!strict
--!optimize 2

local core = require("./roblox_packages/core")
local types = require("@self/types")

local decode = require("@self/decode")
local encode = require("@self/encode")

export type DecodeSource = core.DecodeSource
export type Frame = core.Frame
export type BitmapRegion = core.BitmapRegion

export type ColorSpace = types.ColorSpace
export type CriticalChunk = types.CriticalChunk
export type AncillaryChunk = types.AncillaryChunk
export type Chunk = types.Chunk

export type DecodeErrorCode = decode.DecodeErrorCode
export type DecodeError = decode.DecodeError
export type ReadErrorCode = decode.ReadErrorCode
export type ReadError = decode.ReadError
export type DecodeOptions = decode.DecodeOptions
export type Decoded = decode.Decoded

return table.freeze {
	decode = decode,
	encode = encode,
}
