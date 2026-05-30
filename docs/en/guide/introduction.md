# Introduction

Picguin is a pure-Luau, strictly typed collection of high-performance image codecs,
providing straightforward decoding & encoding for a growing range of formats.

- Each codec is published as a [pesde](https://pesde.dev) package under the `picguin/` namespace.
- All codecs export `decode()` and `encode()` functions.  
  For decode-only formats, `encode()` returns an `"unsupported"` error.  
  <span class="subtext">(for more information, see [Shared Types, Codecs](./shared#codecs))</span>

## Example Usage

Using Picguin's [PNG](./png/) codec to decode an image:

```bash
# package installation
pesde add picguin/png
pesde install
```

```luau
local png = require("@packages/png")
local image = require("some/image/module")

local source: buffer -- raw PNG data

local parsed, err = png.decode(source, {
	crc = "none" -- (PNG-specific) disable crc checks, improving parsing speed
})
if parsed == nil then
	error(`error ({err.code}): {err.message}`)
end

local width, height = parsed.width, parsed.height

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
