# Encoding example
#
# The following pipeline takes a raw audio file and encodes it as G.711 A-law.

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_ffmpeg_plugin,
   path: __DIR__ |> Path.join("..") |> Path.expand(), override: true},
  :membrane_raw_audio_parser_plugin,
  :membrane_raw_audio_format,
  :membrane_file_plugin,
  :req
])

raw_audio =
  Req.get!(
    "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-s16le-8kHz-mono.raw"
  ).body

File.write!("input.raw", raw_audio)

defmodule Encoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure =
      child(:source, %Membrane.File.Source{chunk_size: 40_960, location: "input.raw"})
      |> child(:parser, %Membrane.RawAudioParser{
        stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 8000,
          channels: 1
        }
      })
      |> child(:encoder, Membrane.G711.FFmpeg.Encoder)
      |> child(:sink, %Membrane.File.Sink{location: "output.al"})

    {[spec: structure], %{}}
  end

  @impl true
  def handle_element_end_of_stream(:sink, _pad, _ctx, state) do
    {[terminate: :shutdown], state}
  end

  @impl true
  def handle_element_end_of_stream(_child, _pad, _ctx, state) do
    {[], state}
  end
end

# Start and monitor the pipeline
{:ok, _supervisor_pid, pipeline_pid} = Membrane.Pipeline.start_link(Encoding.Pipeline)
ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, _reason} ->
    System.stop()
end
