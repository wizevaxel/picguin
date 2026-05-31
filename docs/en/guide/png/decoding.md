# PNG: Decoding

<!--@include: ./notes.md -->

## Options

`decode()` accepts an optional `png.DecodeOptions` table to configure decoding behavior:

- `options.crc`: String literal specifying which chunk checksums are validated.
  - `"all"` (default): Validates all chunks, any mismatch triggers a fatal error.
  - `"critical"`: Validates only critical chunks, ancillary chunks are skipped.
  - `"none"`: Checksum validation is skipped entirely.

## Static Image Example

Below, we decode the static image (or the first frame) from a source PNG.  
CRCs are skipped, and parameters for [`cel()`](../shared#parsed) are left at defaults (frame 0, RGBA8 output)

```luau
local parsed, err = png.decode(source, {
	crc = "none"
})
if parsed == nil then
	error(`error ({err.code}): {err.message}`)
end

local cel, err = parsed.cel()
if cel == nil then
	error(`error ({err.code}): {err.message}`)
end
```

## Features

- **Color types:** Truecolor, grayscale, and indexed color are all supported.
- **16-bit depth:** Supported. Use a 16-bit color target in `cel()` to preserve full color depth.
- **Metadata:** A public API to read specific metadata is planned.
- **APNG:** Currently not supported, will be implemented soon.
- **Interlacing:** Currently not supported, will be implemented after APNG.
