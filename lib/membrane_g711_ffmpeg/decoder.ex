defmodule Membrane.G711.FFmpeg.Decoder do
  @moduledoc """
  Membrane element that decodes audio in G711 format. It is backed by decoder from FFmpeg.

  At the moment, only A-law is supported.
  """

  use Membrane.Filter

  require Membrane.G711
  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.G711.FFmpeg.Common
  alias Membrane.{G711, RawAudio, RemoteStream}

  def_input_pad :input,
    demand_mode: :auto,
    demand_unit: :buffers,
    accepted_format: any_of(%RemoteStream{type: :bytestream}, %G711{encoding: :PCMA})

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format: %RawAudio{
      channels: G711.num_channels(),
      sample_rate: G711.sample_rate()
    }

  @impl true
  def handle_init(_ctx, _opts) do
    state = %{decoder_ref: nil}

    {[], state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    case Native.decode(buffer.payload, state.decoder_ref) do
      {:ok, frames} ->
        {Common.wrap_frames(frames), state}

      {:error, reason} ->
        raise "Native decoder failed to decode the payload: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    with buffers <- flush_decoder_if_exists(state),
         {:ok, new_decoder_ref} <- Native.create() do
      stream_format = generate_stream_format(new_decoder_ref)
      actions = buffers ++ [stream_format: {:output, stream_format}]
      {actions, %{state | decoder_ref: new_decoder_ref}}
    else
      {:error, reason} -> raise "Failed to create native decoder: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    buffers = flush_decoder_if_exists(state)
    actions = buffers ++ [end_of_stream: :output]
    {actions, state}
  end

  defp flush_decoder_if_exists(%{decoder_ref: nil}), do: []

  defp flush_decoder_if_exists(%{decoder_ref: decoder_ref}) do
    with {:ok, frames} <- Native.flush(decoder_ref) do
      Common.wrap_frames(frames)
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
end
