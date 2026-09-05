<div align="center">
	<picture>
		<source media="(prefers-color-scheme: dark)" srcset="docs/public/picguin-heading-dark.svg" />
		<img src="docs/public/picguin-heading-light.svg" height="192" />
	</picture>
</div>

<div align="center">

[![docs](https://badgen.net/badge/picguin/docs?label=&color=f0546e&labelColor=cc4053&icon=gitbook)](https://wizevaxel.github.io/picguin/)
[![forum](https://badgen.net/badge/picguin/forum?label=&color=5b92d6&labelColor=4e7fbb&icon=roblox-studio)](https://devforum.roblox.com/t/4667402)
[![license](https://badgen.net/static/license/MIT?color=56c46a&labelColor=47a162)](https://github.com/wizevaxel/picguin/blob/main/LICENSE)

</div>

##

**Picguin** is a collection of pure Luau image codecs for a growing range of formats.  
It provides a uniform interface for decoding & encoding.

- Type-safe, carefully optimized for speed and memory efficiency
- Lightweight implementations with zero dependencies
- Compatible with Roblox, Lune, and other Luau runtimes
- Structured from the ground up to accommodate new formats

> [!WARNING]
> **Picguin is in early development**, and the interface across codecs is subject to change.  
> All packages will remain pre-v1.0.0 until the design is finalized.

## Get Started

[**View the documentation**](https://wizevaxel.github.io/picguin/guide/introduction) to get started with Picguin.

**Simplified happy-path usage (PNG):**

```luau
local png = require("@packages/png")

local source: buffer -- png binary data

local parsed = png.decode(source)  -- decode headers, metadata, etc
local cel = parsed.cel(0, "rgba8") -- decode frame 0 bitmap, region, duration, etc
```

## Codecs

See [Introduction, **Installation**](https://wizevaxel.github.io/picguin/guide/introduction#installation) for an installation guide.

<!-- prettier-ignore -->
| Format | [pesde](https://pesde.dev/search?q=picguin) Package | `.rbxm` Releases |
| - | - | - |
| [**PNG**](https://wizevaxel.github.io/picguin/guide/png/) | `picguin/png` | [**Latest** (**v0.1.1**)](https://github.com/wizevaxel/picguin/releases/png@v0.1.1) <br> [All Releases](https://github.com/wizevaxel/picguin/releases?q=png%40) |
