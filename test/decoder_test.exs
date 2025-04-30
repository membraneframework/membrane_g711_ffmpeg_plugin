defmodule DecoderTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.G711.FFmpeg.Decoder
  alias Membrane.Testing.Pipeline

  @fixtures_dir "test/fixtures/decode/"
  @end_of_stream_timeout_ms 500

  defp prepare_paths(extension, tmp_dir) do
    in_path = Path.join(@fixtures_dir, "input.#{extension}")
    ref_path = Path.join(@fixtures_dir, "reference-s16le.raw")
    out_path = Path.join(tmp_dir, "output-decode.raw")
    {in_path, ref_path, out_path}
  end

  defp make_pipeline(in_path, out_path) do
    Pipeline.start_link_supervised!(
      spec:
        child(:file_src, %Membrane.File.Source{chunk_size: 40_960, location: in_path})
        |> child(:decoder, Decoder)
        |> child(:sink, %Membrane.File.Sink{location: out_path})
    )
  end

  defp assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert byte_size(a) == byte_size(b)
    assert a == b
  end

  defp perform_decoding_test(extension, tmp_dir) do
    {in_path, ref_path, out_path} = prepare_paths(extension, tmp_dir)

    pipeline = make_pipeline(in_path, out_path)
    assert_end_of_stream(pipeline, :sink, :input, @end_of_stream_timeout_ms)
    Pipeline.terminate(pipeline)
    assert_files_equal(out_path, ref_path)
  end

  describe "DecodingPipeline should" do
    @describetag :tmp_dir
    test "decode a 21s long A-law file", ctx do
      perform_decoding_test("al", ctx.tmp_dir)
    end
  end
end
