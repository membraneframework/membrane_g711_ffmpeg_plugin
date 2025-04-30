# Decoding example
#
# The following pipeline takes a G.711 file and decodes it to the raw audio.
# Use `--encoding` option to choose between `ALAW` (default) or `ULAW` variants

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_ffmpeg_plugin,
   path: __DIR__ |> Path.join("..") |> Path.expand(), override: true},
  :membrane_file_plugin,
  :membrane_hackney_plugin
])

g711_alaw =
  Req.get!(
    "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-alaw-8kHz-mono.raw"
  ).body

File.write!("input.al", g711_alaw)

defmodule Decoding.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, opts) do
    encoding = opts[:encoding]

    {name, ext} =
      case encoding do
        :PCMA -> {"pcma", "al"}
        :PCMU -> {"pcmu", "ul"}
      end

    url =
      "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/beep-#{name}-8kHz-mono.#{ext}"

    structure =
      child(:source, %Membrane.Hackney.Source{location: url})
      |> child(:decoder, %Membrane.G711.FFmpeg.Decoder{encoding: encoding})
      |> child(:sink, %Membrane.File.Sink{location: "output.raw"})

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
  Membrane.Pipeline.start_link(Decoding.Pipeline, encoding: encoding)

ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, _reason} ->
    System.stop()
end
