# Decoding example
#
# The following pipeline takes a G.711 A-law file and decodes it to the raw audio.

Logger.configure(level: :info)

Mix.install([
  :membrane_g711_ffmpeg_plugin,
  :membrane_file_plugin,
  :req
])

g711_alaw = Req.get!("https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-alaw-8kHz-mono.raw").body
File.write!("input.al", g711_alaw)

defmodule Decoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure =
      child(%Membrane.File.Source{chunk_size: 40_960, location: "input.al"})
      |> child(Membrane.G711.FFmpeg.Decoder)
      |> child(%Membrane.File.Sink{location: "output.raw"})

    {[spec: structure], %{}}
  end
end

Membrane.Pipeline.start_link(Decoding.Pipeline)
