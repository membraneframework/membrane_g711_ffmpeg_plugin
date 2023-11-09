defmodule Encoder.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.G711.FFmpeg.Encoder.Native
  alias Membrane.Payload

  @fixtures_dir "test/fixtures/encode/"

  test "Encode A-law from s16le" do
    in_path = Path.join(@fixtures_dir, "input-s16le.raw")
    ref_path = Path.join(@fixtures_dir, "reference.al")

    assert {:ok, file} = File.read(in_path)
    assert {:ok, encoder_ref} = Native.create(:s16le)
    assert {:ok, iodata} = Native.encode(file, encoder_ref)
    assert {:ok, []} = Native.flush(encoder_ref)

    out_file =
      iodata
      |> Enum.map(&Payload.to_binary/1)
      |> IO.iodata_to_binary()

    assert {:ok, ref_file} = File.read(ref_path)
    assert byte_size(out_file) == byte_size(ref_file)
    assert out_file == ref_file
  end
end
