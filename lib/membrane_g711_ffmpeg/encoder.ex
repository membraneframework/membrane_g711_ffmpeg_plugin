defmodule Membrane.G711.FFmpeg.Encoder do
  @moduledoc """
  Membrane element that encodes raw audio frames to G711 format (A-law and μ-law are supported).
  It is backed by encoder from FFmpeg.

  The element expects that each received buffer has whole samples, so the parser
  (`Membrane.Element.RawAudio.Parser`) may be required in a pipeline before
  the encoder. The amount of samples in a buffer may vary.

  Additionally, the encoder has to receive proper stream_format (see accepted format on input pad)
  before any encoding takes place.
  """

  use Membrane.Filter

  require Membrane.G711

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.{G711, RawAudio}

  def_options encoding: [
                spec: :PCMA | :PCMU,
                description: "G.711 encoding to use (A-law or μ-law)",
                default: :PCMA
              ]

  def_input_pad :input,
    flow_control: :auto,
    accepted_format: %RawAudio{
      channels: G711.num_channels(),
      sample_rate: G711.sample_rate(),
      sample_format: :s16le
    }

  def_output_pad :output,
    flow_control: :auto,
    accepted_format: %G711{encoding: encoding} when encoding in [:PCMA, :PCMU]

  @impl true
  def handle_init(_ctx, opts) do
    state = %{
      encoder_ref: nil,
      encoding: opts.encoding,
      next_pts: nil
    }

    {[], state}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    state = %{state | next_pts: buffer.pts}

    case Native.encode(buffer.payload, state.encoder_ref) do
      {:ok, frames} ->
        frames_to_buffers(frames, state)

      {:error, reason} ->
        raise "Native encoder failed to encode the payload: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, stream_format, ctx, state) do
    with {buffers, state} <- flush_encoder_if_exists(ctx, state),
         {:ok, new_encoder_ref} <-
           Native.create(stream_format.sample_format, state.encoding) do
      stream_format = generate_stream_format(state)
      actions = buffers ++ [stream_format: {:output, stream_format}]
      {actions, %{state | encoder_ref: new_encoder_ref}}
    else
      {:error, reason} -> raise "Failed to create native encoder: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_end_of_stream(:input, ctx, state) do
    {buffers, state} = flush_encoder_if_exists(ctx, state)
    actions = buffers ++ [end_of_stream: :output]
    {actions, state}
  end

  defp flush_encoder_if_exists(_ctx, %{encoder_ref: nil} = state), do: {[], state}

  defp flush_encoder_if_exists(ctx, %{encoder_ref: encoder_ref} = state) do
    with {:ok, frames} <- Native.flush(encoder_ref) do
      frames_to_buffers(frames, state)
    else
      {:error, reason} -> raise "Native encoder failed to flush: #{inspect(reason)}"
    end
  end

  defp generate_stream_format(%{encoding: encoding}) do
    %G711{encoding: encoding}
  end

  defp frames_to_buffers(frames, state) do
    {buffers, state} =
      frames
      |> Enum.map_reduce(state, fn frame, state ->
        buffer = %Buffer{payload: frame, pts: state.next_pts}
        state = %{state | next_pts: bump_pts(state.next_pts, frame)}
        {buffer, state}
      end)

    {[buffer: {:output, buffers}], state}
  end

  defp bump_pts(nil = _old_pts, _frame), do: nil

  defp bump_pts(old_pts, frame) do
    pts_diff = frame_to_time(frame)
    old_pts + pts_diff
  end

  defp frame_to_time(frame) do
    numerator = byte_size(frame)

    # G.711 uses 8 bits (1 byte) per sample
    bytes_per_sample = 1
    denominator = bytes_per_sample * G711.num_channels() * G711.sample_rate()

    Ratio.new(numerator, denominator)
    |> Membrane.Time.seconds()
  end
end
