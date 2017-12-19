# Exaggerate

** A OpenAPI (swagger) -> Plug code generator for Elixir **


Currently only supports JSON OpenAPI specs.

## Installation

This library requires Elixir 1.6 (because of code prettification)

## Running

```bash
  mix swagger <swaggerfile>
```

The swaggerfile should be in the root directory.  Creates two files, `routes.ex`
and `endpoints.ex`, which are in `$ROOT/lib/$MODULE` where module is generated
from the swaggerfile prefix.

## response encoding.

the default response encoding for JSON is Poison.
