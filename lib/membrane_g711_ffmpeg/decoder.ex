defmodule Membrane.G711.FFmpeg.Decoder do
  @moduledoc """
  Membrane element that decodes audio in G711 format. It is backed by decoder from FFmpeg.

  A-law and μ-law encoding formats are supported.
  """

  use Membrane.Filter

  require Membrane.G711
  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.{G711, RawAudio, RemoteStream}

  def_options encoding: [
                spec: :PCMA | :PCMU | nil,
                description: """
                G.711 encoding to decode (A-law or μ-law)
                Be default it's obtained from the stream format
                with the fallback to PCMA.
                """,
                default: nil
              ]

  def_input_pad :input,
    flow_control: :auto,
    accepted_format:
      any_of(%RemoteStream{}, %G711{encoding: encoding} when encoding in [:PCMA, :PCMU])

  def_output_pad :output,
    flow_control: :auto,
    accepted_format: %RawAudio{
      channels: G711.num_channels(),
      sample_rate: G711.sample_rate()
    }

  @impl true
  def handle_init(_ctx, opts) do
    state = %{
      decoder_ref: nil,
      encoding: opts.encoding,
      next_pts: nil
    }

    {[], state}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    state = %{state | next_pts: buffer.pts}

    case Native.decode(buffer.payload, state.decoder_ref) do
      {:ok, frames} ->
        frames_to_buffers(frames, ctx.pads.output.stream_format, state)

      {:error, reason} ->
        raise "Native decoder failed to decode the payload: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, stream_format, ctx, state) do
    encoding =
      case stream_format do
        %G711{encoding: encoding} ->
          unless state.encoding in [nil, encoding] do
            raise """
            Encoding in the stream format (#{inspect(encoding)}) \
            differs from the encoding specified in options (#{inspect(state.encoding)})
            """
          end

          encoding

        %RemoteStream{} ->
          state.encoding || :PCMA
      end

    with {buffers, state} <- flush_decoder_if_exists(ctx, state),
         {:ok, new_decoder_ref} <- Native.create(encoding) do
      stream_format = generate_stream_format(new_decoder_ref)
      actions = buffers ++ [stream_format: {:output, stream_format}]
      {actions, %{state | decoder_ref: new_decoder_ref}}
    else
      {:error, reason} -> raise "Failed to create native decoder: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_end_of_stream(:input, ctx, state) do
    {buffers, state} = flush_decoder_if_exists(ctx, state)
    actions = buffers ++ [end_of_stream: :output]
    {actions, state}
  end

  defp flush_decoder_if_exists(_ctx, %{decoder_ref: nil} = state), do: {[], state}

  defp flush_decoder_if_exists(ctx, %{decoder_ref: decoder_ref} = state) do
    with {:ok, frames} <- Native.flush(decoder_ref) do
      frames_to_buffers(frames, ctx.pads.output.stream_format, state)
    else
      {:error, reason} -> raise "Native decoder failed to flush: #{inspect(reason)}"
    end
  end

  defp generate_stream_format(decoder_ref) do
    with {:ok, sample_format} <- Native.get_metadata(decoder_ref) do
      %RawAudio{
        channels: G711.num_channels(),
        sample_rate: G711.sample_rate(),
        sample_format: sample_format
      }
    else
      {:error, reason} -> raise "Native encoder failed to provide metadata: #{inspect(reason)}"
    end
  end

  defp frames_to_buffers(frames, stream_format, state) do
    {buffers, state} =
      frames
      |> Enum.map_reduce(state, fn frame, state ->
        buffer = %Buffer{payload: frame, pts: state.next_pts}
        state = %{state | next_pts: bump_pts(state.next_pts, frame, stream_format)}
        {buffer, state}
      end)

    {[buffer: {:output, buffers}], state}
  end

  defp bump_pts(nil = _old_pts, _frame, _stream_format), do: nil

  defp bump_pts(old_pts, frame, stream_format) do
    pts_diff =
      byte_size(frame)
      |> RawAudio.bytes_to_time(stream_format)

    old_pts + pts_diff
  end
end
