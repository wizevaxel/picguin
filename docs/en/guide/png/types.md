---
next: false
---

# PNG: Types

<!--@include: ./notes.md -->

## General Types

### `ColorSpace`

```luau
"truecolor" | "grayscale" | "indexed"
```

A string literal specifying the color type of an image.

---

### `Chunk`

Equivalent to `CriticalChunk | AncillaryChunk`.

### `CriticalChunk`

```luau
| "IHDR" | "PLTE" | "IDAT" | "IEND"
```

### `AncillaryChunk`

```luau
| "tRNS" | "cHRM" | "gAMA" | "iCCP"
| "sBIT" | "sRGB" | "cICP" | "mDCV"
| "cLLI" | "tEXt" | "zTXt" | "iTXt"
| "bKGD" | "pHYs" | "sPLT" | "eXIf"
| "tIME" | "acTL" | "fcTL" | "fdAT"
```

## Decode Types

### `Parsed`

```luau
{
	width: number,
	height: number,
	frames: number,
	alpha: boolean,

	headers: {
		interlacing: boolean,
		channels: number,
		bit_depth: number,
		color_space: types.ColorSpace,
	},
	palette: {number}?,

	cel: (frame: number?, target: ColorTarget?) -> (Cel?, CelError),
}
```

| Property  | Description                                                                    |
| --------- | ------------------------------------------------------------------------------ |
| `headers` | Image information obtained from the IHDR chunk.                                |
| `palette` | Array of colors assigned to palette indexes. `nil` if image has no PLTE chunk. |
| `...`     | (see [`Parsed`](../shared#parsed))                                             |

PNG-specific extension of [`Parsed`](../shared#parsed).

`palette` values contain the RGBA components of the color corresponding to their index
packed sequentially in little-endian byte order.

---

### `DecodeOptions`

```luau
{
	crc: ("all" | "critical" | "none")?,
}
```

| Property | Description                                                    |
| -------- | -------------------------------------------------------------- |
| `crc`    | String literal specifying which chunk checksums are validated. |

PNG-specific decode options accepted by [`decode()`](../shared#codecs).

---

### `DecodeError`

Equivalent to [`Error<DecodeErrorCode>`](../shared#error).

### `DecodeErrorCode`

```luau
| "unsupported"
| "overflow"
| "unexpected_eof"
| "invalid_signature"
| "invalid_crc"
| "invalid_length"
| "invalid_header"
| "unknown_chunk"
| "missing_chunk"
```

---

### `CelError`

Equivalent to [`Error<CelErrorCode>`](../shared#error).

### `CelErrorCode`

```luau
| "unsupported"
| "invalid_header"
| "invalid_filter"
| "invalid_option"
```

---

## Encode Types

(TBD)
