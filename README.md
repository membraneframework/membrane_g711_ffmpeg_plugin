# Membrane G.711 FFmpeg plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_g711_ffmpeg_plugin.svg)](https://hex.pm/packages/membrane_g711_ffmpeg_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_g711_ffmpeg_plugin)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/membrane_g711_ffmpeg_plugin.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/membrane_g711_ffmpeg_plugin)

This package provides G.711 audio decoder, encoder and parser. The decoder and encoder are based on [ffmpeg](https://www.ffmpeg.org).

Both G.711 A-law (PCMA) and μ-law (PCMU) formats are supported.

It is part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_g711_ffmpeg_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_g711_ffmpeg_plugin, "~> 0.1.4"}
  ]
end
```

This package depends on the [ffmpeg](https://www.ffmpeg.org) libraries. The precompiled builds will be pulled and linked automatically. However, should there be any problems, consider installing it manually.

### Manual installation of dependencies

Refer to [ffmpeg page](https://www.ffmpeg.org) for detailed installation instructions.

## Usage

For usage examples, refer to [the scripts in `examples/` directory](https://github.com/jellyfish-dev/membrane_g711_ffmpeg_plugin/tree/main/examples/).

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_template_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_template_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
