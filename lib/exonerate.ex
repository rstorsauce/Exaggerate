defmodule Exonerate do
  def error_reduction(arr) when is_list(arr), do: arr |> Enum.reduce(:ok, &Exonerate.error_reduction/2)
  def error_reduction(:ok, :ok), do: :ok
  def error_reduction(:ok, err), do: err
  def error_reduction(err, _), do: err
end
