defmodule Membrane.G711.FFmpeg.Parser do
  @moduledoc """
  This element is responsible for parsing audio in G711 format.
  The Parser ensures that output buffers have whole samples.
  The parser doesn't ensure that in each output buffer, there will be the same number of samples.
  """

  use Membrane.Filter

  require Membrane.G711

  alias Membrane.{Buffer, G711, RawAudio, RemoteStream}

  # For calculating timestamps using functions from `membrane_raw_audio_format`
  @g711_faux_stream_format %RawAudio{
    sample_rate: G711.sample_rate(),
    channels: G711.num_channels(),
    sample_format: :s8
  }

  def_options stream_format: [
                spec: G711.t() | nil,
                description: """
                The stream format of the output pad.
                It has to be specified if `Membrane.RemoteStream` will be received on the `:input` pad.
                """,
                default: nil
              ],
              overwrite_pts?: [
                spec: boolean(),
                description: """
                If set to true, the parser will add timestamps based on payload duration.
                """,
                default: false
              ],
              pts_offset: [
                spec: non_neg_integer(),
                description: """
                If set to a value different than 0, the parser will start timestamps from offset.
                It's only valid when `overwrite_pts?` is set to true.
                """,
                default: 0
              ]

  def_input_pad :input,
    demand_mode: :auto,
    accepted_format: any_of(G711, RemoteStream),
    availability: :always

  def_output_pad :output,
    demand_mode: :auto,
    availability: :always,
    accepted_format: G711

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:next_pts, options.pts_offset)
      |> Map.put(:acc, <<>>)

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, input_stream_format, _ctx, state) do
    case {input_stream_format, state.stream_format} do
      {%RemoteStream{}, nil} ->
        raise """
        You need to specify `stream_format` in options if `Membrane.RemoteStream` will be received on the `:input` pad
        """

      {_input_format, nil} ->
        {[stream_format: {:output, input_stream_format}],
         %{state | stream_format: input_stream_format}}

      {%RemoteStream{}, stream_format} ->
        {[stream_format: {:output, stream_format}], state}

      {stream_format, stream_format} ->
        {[stream_format: {:output, stream_format}], state}

      _else ->
        raise """
        Stream format on input pad: #{inspect(input_stream_format)}
        is different than the one passed in option: #{inspect(state.stream_format)}
        """
    end
  end

  @impl true
  def handle_process(:input, buffer, _ctx, %{overwrite_pts?: overwrite_pts?} = state) do
    parsed_payload = buffer.payload

    if parsed_payload == <<>> do
      {[], state}
    else
      parsed_buffer = %Buffer{buffer | payload: parsed_payload}

      {parsed_buffer, state} =
        if overwrite_pts?, do: overwrite_pts(parsed_buffer, state), else: {parsed_buffer, state}

      {[buffer: {:output, parsed_buffer}], state}
    end
  end

  defp overwrite_pts(buffer, %{next_pts: next_pts} = state) do
    duration = buffer.payload |> byte_size() |> RawAudio.bytes_to_time(@g711_faux_stream_format)

    {%{buffer | pts: next_pts}, %{state | next_pts: next_pts + duration}}
  end
end
