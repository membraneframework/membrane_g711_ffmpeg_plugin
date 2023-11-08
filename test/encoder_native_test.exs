defmodule Encoder.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.G711.FFmpeg.Encoder.Native
  alias Membrane.Payload

  @fixtures_dir "test/fixtures/encode/"

  test "Encode 8000 A-law samples from s16le" do
    in_path = Path.join(@fixtures_dir, "input-s16le.raw")
    ref_path = Path.join(@fixtures_dir, "reference.al")

    assert {:ok, file} = File.read(in_path)
    assert {:ok, encoder_ref} = Native.create(:s16le)
    assert <<frame::bytes-size(16_000), _rest::binary>> = file
    assert {:ok, [frame]} = Native.encode(frame, encoder_ref)
    assert {:ok, []} = Native.flush(encoder_ref)
    assert Payload.size(frame) == 8_000
    assert {:ok, ref_file} = File.read(ref_path)
    assert <<ref_frame::bytes-size(8_000), _rest::binary>> = ref_file
    assert Payload.to_binary(frame) == ref_frame
  end
end
