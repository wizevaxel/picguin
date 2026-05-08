--!strict
--!optimize 2

export type Error<Code> = {
	code: Code,
	message: string,
}

export type ColorSpace = "truecolor" | "grayscale" | "indexed"

export type CriticalChunk =
	| "IHDR" | "IDAT" | "PLTE" | "IEND"
export type AncillaryChunk =
	| "tRNS" | "gAMA" | "cHRM" | "sRGB"
	| "iCCP" | "pHYs" | "bKGD" | "tEXt"
	| "iTXt" | "zTXt" | "tIME" | "eXIf"
export type Chunk = CriticalChunk | AncillaryChunk

return nil
