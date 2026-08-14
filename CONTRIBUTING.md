# Contributing

Please make sure to [**view the documentation**](https://wizevaxel.github.io/picguin/guide/introduction) first, for info on Picguin's usage and concepts.  

## Setup

Install [Rokit](https://github.com/rojo-rbx/rokit), then clone and setup:

```bash
git clone https://github.com/wizevaxel/picguin.git
cd picguin
rokit install
```

## Info

Each codec is packaged separately under `packages/`, and versioned individually.

### Practices

- Please avoid editing configurations such as `pesde.toml`.
- TBD

## Formatting

> [!CAUTION] Notice
> **Please avoid using formatters such as Stylua when contributing!**

- Strictly use tab indentation.
- TBD

### Casing

|            Kind | Casing                 |
| --------------: | ---------------------- |
|       variables | `snake_case`           |
|       functions | `snake_case`           |
| string literals | `snake_case`           |
|       constants | `SCREAMING_SNAKE_CASE` |
|           types | `PascalCase`           |
|         modules | `snake_case`           |

### Commits

Commit messages should be formatted as follows:

```
[scope:] [component:] <description>

[optional body]
```

e.g.  
`png: zlib: optimize window backreferences`  
`docs: benchmarks: record png@v0.3.0`  
`docs: fix favicon`  
`update tooling`  

### Branches

Branch names should be formatted as follows:

```
[scope/]<description>
```

e.g.  
`png/apng`  
`docs/style-improvements`  
`integer-upgrade`  

## Testing

TBD