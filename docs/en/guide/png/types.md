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

## Decode Types

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

## Encode Types

(TBD)
