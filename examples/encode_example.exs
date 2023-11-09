# Encoding example
#
# The following pipeline takes a raw audio file and encodes it as G.711 A-law.

Logger.configure(level: :info)

Mix.install([
  :membrane_g711_ffmpeg_plugin,
  :membrane_file_plugin,
  :req
])

raw_audio = Req.get!("https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-s16le-8kHz-mono.raw").body
File.write!("input.raw", raw_audio)

defmodule Encoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure =
      child(%Membrane.File.Source{chunk_size: 40_960, location: "input.raw"})
      |> child(Membrane.G711.FFmpeg.Encoder)
      |> child(%Membrane.File.Sink{location: "output.al"})

    {[spec: structure], %{}}
  end
end

Membrane.Pipeline.start_link(Encoding.Pipeline)
