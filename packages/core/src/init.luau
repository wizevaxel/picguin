--!strict

export type ColorFormat =
	| "rgba8"
	| "rgb8"

export type AlphaFormat =
	| "alpha"
	| "black"
	| "white"

export type ErrorCode =
	| "unsupported"
	| "overflow"
	| "unexpected_eof"

export type Error<Code> = {
	code: Code,
	message: string,
}

export type DecodeSource = buffer | string

export type Decoded<ReadErrorCode, Extension> = {
	codec: string,

	width: number,
	height: number,

	read: (ReadOptions) -> (ReadResult?, Error<ReadErrorCode>),
} & Extension

export type ReadOptions = {
	format: ColorFormat?,
	frame: number?,
	composite: boolean?,
	alpha: AlphaFormat?,
}

export type ReadResult = {
	bitmap: buffer,
	region: PixelRegion?,
	duration: number?,
}

export type PixelRegion = {
	x: number,
	y: number,
	width: number,
	height: number,
}

local function convert_source(source: DecodeSource): buffer
	return type(source) == "buffer" and source or buffer.fromstring(source)
end

return table.freeze {
	convert_source = convert_source
}
