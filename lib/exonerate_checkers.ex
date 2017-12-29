defmodule Exonerate.Checkers do
  @moduledoc """
    contains a series of functions that are used to aid in validation of
    JSONSchema maps.
  """

  def check_additionalitems(arr, item_fun, additionalitem_fun) when is_list(arr) do
    ((arr |> Enum.slice(length(item_fun)..-1) |> Enum.map(additionalitem_fun))
      ++ (arr |> Enum.zip(item_fun) |> Enum.map(fn {x,f} -> f.(x) end)))
      |> Exonerate.error_reduction
  end
end
