defmodule Decoder.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.G711.FFmpeg.Decoder.Native
  alias Membrane.Payload

  @fixtures_dir "test/fixtures/decode/"

  test "Decode A-law" do
    in_path = Path.join(@fixtures_dir, "input.al")
    ref_path = Path.join(@fixtures_dir, "reference-s16le.raw")

    assert {:ok, file} = File.read(in_path)
    assert {:ok, decoder_ref} = Native.create()
    assert {:ok, iodata} = Native.decode(file, decoder_ref)
    assert {:ok, []} = Native.flush(decoder_ref)

    out_file =
      iodata
      |> Enum.map(&Payload.to_binary/1)
      |> IO.iodata_to_binary()

    assert {:ok, ref_file} = File.read(ref_path)
    assert byte_size(out_file) == byte_size(ref_file)
    assert out_file == ref_file
  end
end
