# Introduction

**Picguin** is a collection of pure Luau image codecs for a growing range of formats.  
It provides a uniform interface for decoding & encoding.

- Type-safe, carefully optimized for speed and memory efficiency
- Lightweight implementations with zero dependencies
- Compatible with Roblox, Lune, and other Luau runtimes
- Structured from the ground up to accommodate new formats

## Installation

Picguin codecs can be individually installed using the following methods:

::: tabs

=== Using pesde (package manager)

Each codec is published under the `picguin/` scope in the pesde index.  
Install [pesde](https://docs.pesde.dev/), and run the following commands in your project:

```bash
pesde add picguin/codec
pesde install
```

<span class="subtext">(replace `codec` with your desired format, e.g. `png`)</span>

The codec will be installed under the target environment defined in your `pesde.toml`.

=== Using .rbxm releases

For non-pesde environments, codecs are released on GitHub as prebuilt `.rbxm` files.

View the list under [README, **Codecs**](https://github.com/wizevaxel/picguin/blob/main/README.md#codecs) for latest releases of each codec.

:::

## Example Usage

Below is typical usage of the [PNG](./png/) codec to decode a static image:

```luau
local png = require("@packages/png")
local image = require("some/image/module")

local source: buffer -- png binary data

local parsed, err = png.decode(source, {
	crc = "none" -- (png-specific) disable crc checks, improving parsing speed
})
if parsed == nil then
	error(`parse error ({err.code}): {err.message}`)
end

print(`parsed {parsed.width}x{parsed.height} image`)

local cel, err = parsed.cel(0, "rgba8") -- frame 0 -> rgba8 bitmap (default)
if cel == nil then
	error(`cel error ({err.code}): {err.message}`)
end

image:write(cel.bitmap, cel.region.size, cel.region.position)
```

::: warning

**Picguin is in early development**, and the interface across codecs is subject to change.  
All packages will remain pre-v1.0.0 until the design is finalized.

:::
