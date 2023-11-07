defmodule Membrane.G711 do
  @moduledoc """
  This module provides format definition for G.711 audio stream
  """

  @typedoc """
  Companding algorithm used:
  - `:PCMA` - G.711 A-law
  - `:PCMU` - G.711 mu-law
  """
  @type encoding :: :PCMA | :PCMU

  @type t :: %__MODULE__{
          encoding: encoding()
        }

  @enforce_keys [:encoding]
  defstruct @enforce_keys
end
