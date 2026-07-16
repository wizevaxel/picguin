---
next: false
---

# Shared Types

::: warning

**Picguin is in early development**, and the interface across codecs is subject to change.  
All packages will remain pre-v1.0.0 until the design is finalized.

:::

### Notes

 <Badge type="warning">Public Base</Badge> - Always exported directly from a codec, with format-specific extensions.  
<span class="subtext">(e.g. PNG exports [`png.Parsed`](./png/types#parsed), an extension of [`Parsed`](#parsed) with additional properties)</span>

 <Badge type="danger">Private Base</Badge> - Inherited by types internally, never exported directly from a codec.  
<span class="subtext">(e.g. PNG exports [`png.DecodeError`](./png/types#decodeerror), equivalent to [`Error<png.DecodeErrorCode>`](#error))</span>

## Codecs

All codecs export this specific shape:

```luau
{
	version: string,
	decode: (source: buffer, options: DecodeOptions?) -> (Parsed?, DecodeError),
	encode: () -> (), -- TBD
}
```

| Property  | Description                                                       |
| --------- | ----------------------------------------------------------------- |
| `version` | The current version of the codec package.                         |
| `decode`  | Parses a source image into a format-specific [`Parsed`](#parsed). |
| `encode`  | (TBD)                                                             |

For decode-only formats, `encode()` returns an `"unsupported"` error.

## General Types

### `Error<Code>` <Badge type="danger">Private Base</Badge> {#error}

```luau
{
	code: "ok",
	message: "",
} | {
	code: Code,
	message: string,
}
```

| Property  | Description                                                                      |
| --------- | -------------------------------------------------------------------------------- |
| `code`    | String literal representing the error. `"ok"` if no fatal error was encountered. |
| `message` | Human-readable string providing more detail on the error.                        |

All public functions return a type inherited from `Error<Code>` to indicate success/failure.

## Decode Types

### `Parsed` <Badge type="warning">Public Base</Badge> {#parsed}

```luau
{
	width: number,
	height: number,
	frames: number,

	cel: (frame: number?, target: ColorTarget?) -> (Cel?, CelError),
}
```

| Property | Description                                                                                                                     |
| -------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `width`  | Image width in pixels.                                                                                                          |
| `height` | Image height in pixels.                                                                                                         |
| `frames` | Image frame count. `1` by default if animation is unsupported.                                                                  |
| `cel`    | Decodes the image or a specified frame into a [`Cel`](#cel). <br> Default parameters: <code>(0, ["rgba8"](#colortarget))</code> |

In `cel()`, the `frame` parameter wraps around the frame count, and can be negative.

---

### `ColorTarget`

```luau
| "rgba8"
| "rgba16"
```

A string literal specifying the target format for [`Cel.bitmap`](#cel) when calling [`Parsed.cel()`](#parsed).

---

### `Cel`

```luau
{
	bitmap: buffer,
	region: BitmapRegion,
	duration: number,
}
```

| Property   | Description                                                                   |
| ---------- | ----------------------------------------------------------------------------- |
| `bitmap`   | Frame pixel data.                                                             |
| `region`   | Region to write `bitmap` into. Relevant when decoding [APNG](./png/) and GIF. |
| `duration` | Frame duration. `0.0` by default if the image is not animated.                |

A decoded frame returned by [`Parsed.cel()`](#parsed), containing all information necessary to
display the frame and progress animation.

---

### `BitmapRegion`

```luau
{
	size: vector,
	position: vector,
}
```

| Property   | Description                            |
| ---------- | -------------------------------------- |
| `size`     | Size of region in pixels.              |
| `position` | Positional offset of region in pixels. |

Represents a 2D region in pixels.

## Encode Types

(TBD)
