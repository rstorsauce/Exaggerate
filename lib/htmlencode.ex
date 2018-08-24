defmodule Exaggerate.HTMLEncode do

  def encode!(data) when is_map(data), do: data |> Poison.encode!
  def encode!(data) when is_list(data), do: data |> Poison.encode!
  def encode!(data) when is_binary(data), do: data

  def bodyonly(data), do: data

end
