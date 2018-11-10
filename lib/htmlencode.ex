defmodule Exaggerate.HTMLEncode do

  def encode!(data) when is_map(data), do: data |> Jason.encode!
  def encode!(data) when is_list(data), do: data |> Jason.encode!
  def encode!(data) when is_binary(data), do: data

  def bodyonly(data), do: data

end
