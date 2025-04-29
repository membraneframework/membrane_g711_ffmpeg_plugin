module Membrane.G711.FFmpeg.Encoder.Native

state_type "State"

spec create(sample_fmt :: atom, encoding :: atom) ::
       {:ok :: label, state} | {:error :: label, reason :: atom}

spec encode(payload, state) ::
       {:ok :: label, frames :: [payload]}
       | {:error :: label, reason :: atom}

spec flush(state) ::
       {:ok :: label, frames :: [payload]}
       | {:error :: label, reason :: atom}

dirty :cpu, encode: 2, flush: 1
