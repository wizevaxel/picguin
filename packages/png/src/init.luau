--!strict

local core = require("./roblox_packages/core")
local types = require("@self/types")

export type DecodeSource = core.DecodeSource
export type ColorFormat = core.ColorFormat
export type AlphaFormat = core.AlphaFormat
export type ReadOptions = core.ReadOptions
export type ReadResult = core.ReadResult
export type PixelRegion = core.PixelRegion

export type ErrorCode = types.ErrorCode
export type DecodeOptions = types.DecodeOptions
export type Decoded = types.Decoded
export type AncillaryChunk = types.AncillaryChunk

return {
	decode = require("@self/decode"),
	encode = require("@self/encode"),
}
