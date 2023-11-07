defmodule Membrane.G711.FFmpeg.Common do
  @moduledoc false

  @doc """
  Wraps frames in `Membrane.Buffer`s and returns `Membrane.Element.Action`s to take.
  """
  @spec wrap_frames([binary()]) :: [Membrane.Element.Action.t()]
  def wrap_frames([]), do: []

  def wrap_frames(frames) do
    frames
    |> Enum.map(fn frame -> %Membrane.Buffer{payload: frame} end)
    |> then(&[buffer: {:output, &1}])
  end
end
