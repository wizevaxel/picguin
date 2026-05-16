---
next: false
---

Picguin is a pure-Luau, strictly typed collection of high-performance image codecs,
providing straightforward decoders & encoders for a growing range of formats.

- Each codec is published as a [pesde](https://pesde.dev) package under the `picguin/` namespace.
- All codecs export `decode(source, options)` and `encode(pixels, options)` functions.  
  For codecs without encoding support, `encode()` returns an `"unsupported"` error.

---

### Example Usage
Here, we use Picguin's [PNG](./png/) library to decode an image.

```bash
# package installation
pesde add picguin/png
pesde install
```

```luau
local png = require("@packages/png")
local content = require("some/image/module")

local source: buffer | string -- raw PNG file data

-- png.decode(source: buffer | string, options: png.DecodeOptions?) -> png.Image
local image, err = png.decode(source, {
	crc = "none" -- disable crc checks, improving parsing performance
})
if image == nil then
	warn(`error ({err.code}): {err.message}`)
end

-- `image` provides image info and a read method
-- image.read(frame: number?, format: png.ColorFormat?) -> png.Frame
local frame, err = image.read(0, "rgba8") -- frame 0 -> rgba8 bitmap (default)
if frame == nil then
	warn(`error ({err.code}): {err.message}`)
end

content:write(frame.bitmap, frame.region.size, frame.region.position)
```

#### Error Handling

- All exported functions return `(result?, error)`.
- If a fatal error is encountered, `result = nil`. Otherwise, `error.code = "ok"`.

::: warning
Picguin is in early development, and the public API across codecs is subject to change.  
All packages will remain pre-v1.0.0 until a stable design is in place.
:::
