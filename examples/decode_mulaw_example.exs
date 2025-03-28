# Decoding example (μ-law)
#
# The following pipeline takes a G.711 μ-law file and decodes it to the raw audio.

Logger.configure(level: :info)

Mix.install([
  {:membrane_g711_ffmpeg_plugin,
   path: __DIR__ |> Path.join("..") |> Path.expand(), override: true},
  :membrane_file_plugin,
  :req
])

# For this example, we'll use a local file created by encode_mulaw_example.exs
# Alternatively, you could download a μ-law sample file from a URL

defmodule DecodingMulaw.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    structure =
      child(:source, %Membrane.File.Source{chunk_size: 40_960, location: "output.ul"})
      |> child(:decoder, %Membrane.G711.FFmpeg.Decoder{encoding: :PCMU})
      |> child(:sink, %Membrane.File.Sink{location: "output_from_mulaw.raw"})

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
{:ok, _supervisor_pid, pipeline_pid} = Membrane.Pipeline.start_link(DecodingMulaw.Pipeline)
ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^ref, :process, _pipeline_pid, _reason} ->
    System.stop()
end