--!strict
--!optimize 2

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

	read: (number?) -> (Frame?, Error<ReadErrorCode>),
} & Extension

export type Frame = {
	bitmap: buffer,
	region: BitmapRegion?,
	duration: number?,
}

export type BitmapRegion = {
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
