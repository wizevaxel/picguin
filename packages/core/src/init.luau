--!strict

export type DecodeSource = buffer | string

export type ColorFormat =
	| "rgba8"
	| "rgb8"

export type AlphaFormat =
	| "alpha"
	| "black"
	| "white"

export type DecodeRegion = {
	x: number,
	y: number,
	width: number,
	height: number,
}

export type DecodeOptions = {
	format: ColorFormat?,
	frame: number?,
	composite: boolean?,
	alpha: AlphaFormat?,
}

export type DecodeResult = {
	pixels: buffer,
	region: DecodeRegion?,
	duration: number?,
}

export type Decoder<Extension> = {
	codec: string,

	width: number,
	height: number,
	frames: number,

	pixels: (DecodeOptions) -> DecodeResult,
} & Extension

local function convert_source(source: DecodeSource): buffer
	return type(source) == "buffer" and source or buffer.fromstring(source)
end

return table.freeze {
	convert_source = convert_source
}
