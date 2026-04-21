--!strict

local core = require("./roblox_packages/core")
local types = require("@self/types")

local decode = require("@self/decode")
local encode = require("@self/encode")

export type DecodeSource = core.DecodeSource
export type ColorFormat = core.ColorFormat
export type AlphaFormat = core.AlphaFormat
export type ReadOptions = core.ReadOptions
export type ReadResult = core.ReadResult
export type PixelRegion = core.PixelRegion

export type ErrorCode = types.ErrorCode
export type DecodeError = types.DecodeError
export type AncillaryChunk = types.AncillaryChunk

export type DecodeOptions = decode.DecodeOptions
export type Decoded = decode.Decoded

return {
	decode = decode,
	encode = encode,
}
