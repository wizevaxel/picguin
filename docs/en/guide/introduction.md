# Introduction

Picguin is a pure-Luau, strictly typed collection of high-performance image codecs,
providing straightforward decoders & encoders for a growing range of formats.

- Each codec is published as a [pesde](https://pesde.dev) package under the `picguin/` namespace.
- All codecs export `decode(source, options)` and `encode(pixels, options)` functions.  
  For codecs without encoding support, `encode()` returns an `"unsupported"` error.

## Example Usage

Here, we use Picguin's [PNG](./png/) library to decode an image.

```bash
# package installation
pesde add picguin/png
pesde install
```

```luau
local png = require("@packages/png")
local image = require("some/image/module")

local source: buffer -- raw PNG data

-- png.decode(source: buffer, options: png.DecodeOptions?) -> png.Parsed
local parsed, err = png.decode(source, {
	crc = "none" -- disable crc checks, improving parsing performance
})
if parsed == nil then
	error(`error ({err.code}): {err.message}`)
end

-- `parsed` provides parsed image info and a read method
-- parsed.read(frame: number?, target: png.ColorTarget?) -> png.Cel
local cel, err = parsed.read(0, "rgba8") -- frame 0 -> rgba8 bitmap (default)
if cel == nil then
	error(`error ({err.code}): {err.message}`)
end

image:write(cel.bitmap, cel.region.size, cel.region.position)
```

::: warning
Picguin is in early development, and the public API across codecs is subject to change.  
All packages will remain pre-v1.0.0 until a stable design is in place.
:::
