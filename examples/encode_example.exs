# Encoding example
#
# The following pipeline takes a raw audio file and encodes it as G.711 A-law.
# Use `--encoding` option to choose between `ALAW` (default) or `ULAW` variants

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_ffmpeg_plugin,
   path: __DIR__ |> Path.join("..") |> Path.expand(), override: true},
  :membrane_raw_audio_parser_plugin,
  :membrane_raw_audio_format,
  :membrane_file_plugin,
  :membrane_hackney_plugin
])

defmodule Encoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, opts) do
    encoding = opts[:encoding]

    ext =
      case encoding do
        :PCMA -> "al"
        :PCMU -> "ul"
      end

    url =
      "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-s16le-8kHz-mono.raw"

    structure =
      child(:source, %Membrane.Hackney.Source{location: url})
      |> child(:parser, %Membrane.RawAudioParser{
        stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 8000,
          channels: 1
        }
      })
      |> child(:encoder, %Membrane.G711.FFmpeg.Encoder{encoding: encoding})
      |> child(:sink, %Membrane.File.Sink{location: "output.#{ext}"})

    {[spec: structure], %{}}
  end

  @impl true
  def handle_element_end_of_stream(:sink, _pad, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_child, _pad, _ctx, state) do
    {[], state}
  end
end

{opts, _rest} = OptionParser.parse!(System.argv(), strict: [encoding: :string])
encoding = opts |> Keyword.get(:encoding, "PCMA") |> String.upcase() |> String.to_existing_atom()

# Start and monitor the pipeline
{:ok, _supervisor_pid, pipeline_pid} =
  Membrane.Pipeline.start_link(Encoding.Pipeline, encoding: encoding)

ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, _reason} -> :ok
end
