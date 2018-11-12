defimpl Jason.Encoder, for: Plug.Upload do
  def encode(value, opts) do
    value
    |> Map.take([:content_type, :filename])
    |> Map.put(:path, "<internal path value>")
    |> Jason.Encode.map(opts)
  end
end
