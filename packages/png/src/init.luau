--!strict

local core = require("./roblox_packages/core")
local types = require("@self/types")

export type DecodeSource = core.DecodeSource
export type DecodeOptions = types.DecodeOptions
export type Decoder = types.Decoder
export type AncillaryChunk = types.AncillaryChunk

return {
	decode = require("@self/decode"),
	encode = require("@self/encode"),
}
