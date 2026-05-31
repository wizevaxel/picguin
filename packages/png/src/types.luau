--!strict
--!optimize 2

export type Error<Code> = {
	code: "ok",
	message: "",
} | {
	code: Code,
	message: string,
}

export type ColorSpace = "truecolor" | "grayscale" | "indexed"

export type CriticalChunk =
	| "IHDR" | "PLTE" | "IDAT" | "IEND"
export type AncillaryChunk =
	| "tRNS" | "cHRM" | "gAMA" | "iCCP"
	| "sBIT" | "sRGB" | "cICP" | "mDCV"
	| "cLLI" | "tEXt" | "zTXt" | "iTXt"
	| "bKGD" | "pHYs" | "sPLT" | "eXIf"
	| "tIME" | "acTL" | "fcTL" | "fdAT"
export type Chunk = CriticalChunk | AncillaryChunk

return nil
