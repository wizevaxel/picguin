# Introduction

Picguin is a collection of fast, pure Luau image codecs for a growing range of formats.  
It provides a standardized interface for straightforward decoding & encoding.

- Fully strictly typed, optimized using modern techniques for maximum performance
- Lightweight, self-contained implementations with zero dependencies
- Seamlessly compatible with Roblox, Lune, and other Luau runtimes
- Architected to easily scale and support new formats over time

## Installing Codecs

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

For non-pesde environments, codecs are released on GitHub as prebuilt `.rbxm` files,
which you can drop straight into your project.

Links to the latest releases of all codecs are listed in the [repository README](https://github.com/wizevaxel/picguin/blob/main/README.md).  
The **Overview** pages for each codec also provide specific install instructions.

:::

## Example Usage

Below is a typical workflow using the [PNG](./png/) codec to decode a static image:

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

local width, height = parsed.width, parsed.height

local cel, err = parsed.cel(0, "rgba8") -- frame 0 -> rgba8 bitmap (default)
if cel == nil then
	error(`cel error ({err.code}): {err.message}`)
end

image:write(cel.bitmap, cel.region.size, cel.region.position)
```

::: warning
Picguin is in early development, and the public API across codecs is subject to change.  
All packages will remain pre-v1.0.0 until a stable design is in place.
:::
