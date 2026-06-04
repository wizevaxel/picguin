<div align="center">
	<picture>
		<source media="(prefers-color-scheme: dark)" srcset="docs/public/heading-dark.svg" />
		<img src="docs/public/heading-light.svg" height="192" />
	</picture>
</div>

<div align="center">

[![docs](https://badgen.net/badge/picguin/docs?label=&color=f0546e&labelColor=cc4053&icon=gitbook)](https://wizevaxel.github.io/picguin/)
[![license](https://badgen.net/static/license/MIT?color=56c46a&labelColor=47a162)](https://github.com/wizevaxel/picguin/blob/main/LICENSE)

</div>

##

Picguin is a collection of fast, pure Luau image codecs for a growing range of formats.  
It provides a standardized interface for straightforward decoding & encoding.

- Fully type-safe, optimized using modern techniques for maximum performance
- Lightweight, self-contained implementations with zero dependencies
- Seamlessly compatible with Roblox, Lune, and other Luau runtimes
- Architected to easily scale and support new formats over time

> [!WARNING]
> Picguin is in early development, and the public API across codecs is subject to change.  
> All packages will remain pre-v1.0.0 until a stable design is in place.

## Get Started

[**View the documentation**](https://wizevaxel.github.io/picguin/guide/introduction) to get started with Picguin.

**Simplified happy-path usage example (PNG):**

```luau
local png = require("@packages/png")

local source: buffer -- png binary data

local parsed = png.decode(source)  -- decode headers, metadata, etc
local cel = parsed.cel(0, "rgba8") -- decode frame 0 bitmap, region, duration, etc
```

## Codecs

View [Introduction, **Installation**](https://wizevaxel.github.io/picguin/guide/introduction#installation) for a quick installation guide.

<!-- prettier-ignore -->
| Format   | [pesde](https://pesde.dev/search?q=picguin) Package | `.rbxm` Releases |
| -------- | -------------- | - |
| **PNG**  | `picguin/png`  | [**Latest** (**v0.1.1**)](https://github.com/wizevaxel/picguin/releases/png@v0.1.1) <br> [All Releases](https://github.com/wizevaxel/picguin/releases?q=png%40) |
