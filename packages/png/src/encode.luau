--!strict
--!optimize 2

local types = require("./types")

export type EncodeErrorCode =
	| "unsupported"
export type EncodeError = types.Error<EncodeErrorCode>

return function(): (nil, EncodeError)
	return nil, {code = "unsupported", message = "PNG encoding is currently unsupported"}
end
