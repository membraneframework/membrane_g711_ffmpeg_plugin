defmodule EncoderTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.G711.FFmpeg.Encoder
  alias Membrane.RawAudioParser
  alias Membrane.Testing.Pipeline

  @fixtures_dir "test/fixtures/encode/"
  @end_of_stream_timeout_ms 500

  defp prepare_paths(extension, tmp_dir) do
    in_path = Path.join(@fixtures_dir, "input-s16le.raw")
    ref_path = Path.join(@fixtures_dir, "reference.#{extension}")
    out_path = Path.join(tmp_dir, "output-encode.#{extension}")
    {in_path, ref_path, out_path}
  end

  defp make_pipeline(in_path, out_path) do
    Pipeline.start_link_supervised!(
      spec:
        child(:file_src, %Membrane.File.Source{chunk_size: 40_960, location: in_path})
        |> child(:parser, %RawAudioParser{
          stream_format: %Membrane.RawAudio{
            channels: 1,
            sample_rate: 8000,
            sample_format: :s16le
          }
        })
        |> child(:encoder, Encoder)
        |> child(:sink, %Membrane.File.Sink{location: out_path})
    )
  end

  defp assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert byte_size(a) == byte_size(b)
    assert a == b
  end

  defp perform_encoding_test(extension, tmp_dir) do
    {in_path, ref_path, out_path} = prepare_paths(extension, tmp_dir)

    pid = make_pipeline(in_path, out_path)
    assert_end_of_stream(pid, :sink, :input, @end_of_stream_timeout_ms)
    assert_files_equal(out_path, ref_path)
  end

  describe "EncodingPipeline should" do
    @describetag :tmp_dir
    test "encode a 21s long raw s16le file to A-law", ctx do
      perform_encoding_test("al", ctx.tmp_dir)
    end
  end
end
