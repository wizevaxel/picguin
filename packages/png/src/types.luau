--!strict
--!optimize 2

local core = require("../roblox_packages/core")

export type ColorSpace = "truecolor" | "grayscale" | "indexed"

export type CriticalChunk =
	| "IHDR" | "IDAT" | "PLTE" | "IEND"
export type AncillaryChunk =
	| "tRNS" | "gAMA" | "cHRM" | "sRGB"
	| "iCCP" | "pHYs" | "bKGD" | "tEXt"
	| "iTXt" | "zTXt" | "tIME" | "eXIf"
export type Chunk = CriticalChunk | AncillaryChunk

return nil
