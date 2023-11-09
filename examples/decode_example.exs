# Decoding example
#
# The following pipeline takes a G.711 A-law file and decodes it to the raw audio.

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_ffmpeg_plugin, path: __DIR__ |> Path.join("..") |> Path.expand(), override: :true},
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
      child(:source, %Membrane.File.Source{chunk_size: 40_960, location: "input.al"})
      |> child(:decoder, Membrane.G711.FFmpeg.Decoder)
      |> child(:sink, %Membrane.File.Sink{location: "output.raw"})

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
{:ok, _supervisor_pid, pipeline_pid} = Decoding.Pipeline.start_link()
ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, _reason} ->
    System.stop()
end
