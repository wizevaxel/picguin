--!strict

local core = require("./roblox_packages/core")
local types = require("@self/types")

local decode = require("@self/decode")
local encode = require("@self/encode")

export type ColorFormat = core.ColorFormat
export type AlphaFormat = core.AlphaFormat
export type DecodeSource = core.DecodeSource
export type ReadOptions = core.ReadOptions
export type ReadResult = core.ReadResult
export type PixelRegion = core.PixelRegion

export type ColorType = types.ColorType
export type CriticalChunk = types.CriticalChunk
export type AncillaryChunk = types.AncillaryChunk
export type Chunk = types.Chunk

export type DecodeErrorCode = decode.DecodeErrorCode
export type DecodeError = decode.DecodeError
export type ReadErrorCode = decode.ReadErrorCode
export type ReadError = decode.ReadError
export type DecodeOptions = decode.DecodeOptions
export type Decoded = decode.Decoded

return {
	decode = decode,
	encode = encode,
}
