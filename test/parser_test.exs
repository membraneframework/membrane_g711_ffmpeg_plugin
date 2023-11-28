defmodule ParserTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  require Membrane.G711

  alias Membrane.G711.FFmpeg.Parser
  alias Membrane.Testing.{Pipeline, Sink, Source}
  alias Membrane.{Buffer, G711, RawAudio, Time}

  @faux_stream_format %RawAudio{
    channels: G711.num_channels(),
    sample_rate: G711.sample_rate(),
    sample_format: :s8
  }

  @stream_format %G711{encoding: :PCMA}

  @silence_duration Time.milliseconds(10)
  @silence RawAudio.silence(@faux_stream_format, @silence_duration)

  test "parser adds timestamps" do
    buffers = Enum.map(1..10, fn _idx -> @silence end)

    structure = [
      child(:source, %Source{output: buffers, stream_format: @stream_format})
      |> child(:parser, %Parser{overwrite_pts?: true})
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)
    assert_end_of_stream(pipeline, :sink)

    for i <- 0..9 do
      pts = i * @silence_duration
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: ^pts, payload: @silence})
    end
  end

  test "parser adds timestamps with offset" do
    offset = 10
    buffers = Enum.map(1..10, fn _idx -> @silence end)

    structure = [
      child(:source, %Source{output: buffers, stream_format: @stream_format})
      |> child(:parser, %Parser{overwrite_pts?: true, pts_offset: offset})
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)
    assert_end_of_stream(pipeline, :sink)

    for i <- 0..9 do
      pts = i * @silence_duration + offset
      assert_sink_buffer(pipeline, :sink, %Buffer{pts: ^pts, payload: @silence})
    end
  end

  test "parser can have `RemoteStream` as input" do
    structure = [
      child(:source, %Membrane.File.Source{location: "test/fixtures/decode/input.al"})
      |> child(:parser, %Parser{stream_format: @stream_format})
      |> child(:sink, Sink)
    ]

    assert pipeline = Pipeline.start_link_supervised!(structure: structure)
    assert_end_of_stream(pipeline, :sink)
  end
end
