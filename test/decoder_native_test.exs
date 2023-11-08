defmodule Decoder.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.G711.FFmpeg.Decoder.Native
  alias Membrane.Payload

  @fixtures_dir "test/fixtures/decode/"

  test "Decode 8000 A-law samples" do
    in_path = Path.join(@fixtures_dir, "input.al")
    ref_path = Path.join(@fixtures_dir, "reference-s16le.raw")

    assert {:ok, file} = File.read(in_path)
    assert {:ok, decoder_ref} = Native.create()
    assert <<frame::bytes-size(8000), _rest::binary>> = file
    assert {:ok, [frame]} = Native.decode(frame, decoder_ref)
    assert {:ok, []} = Native.flush(decoder_ref)
    assert Payload.size(frame) == 16_000
    assert {:ok, ref_file} = File.read(ref_path)
    assert <<ref_frame::bytes-size(16_000), _rest::binary>> = ref_file
    assert Payload.to_binary(frame) == ref_frame
  end
end
