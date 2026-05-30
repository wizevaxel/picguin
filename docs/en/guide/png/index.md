---
prev: false
---

# PNG: Overview

<!--@include: ./notes.md -->

PNG can be installed using the following methods:

::: tabs

=== Using pesde
All codec packages are published under the `picguin/` namespace.

1. Install [pesde](https://docs.pesde.dev/)
2. Add and install `picguin/png`:
   ```bash
   pesde add picguin/png
   pesde install
   ```
   PNG will be installed under the target environment defined in your `pesde.toml`.

=== Using .rbxm releases
Each GitHub release provides the latest version of all codecs as .rbxm binaries.

1. Navigate to the [latest GitHub release](https://github.com/wizevaxel/picguin/releases/latest)
2. Locate and download the latest `png.rbxm`, and drop it directly into your project.

:::
