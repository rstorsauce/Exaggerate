defmodule Exaggerate do
  def append_if_ok(test, val) do
    case test do
      :ok -> {:ok, val}
      val -> val
    end
  end

  #TODO:  add support for wildcard matches
  def typematch(matchstring, typelist) do
    typelist |> Enum.map(fn typ -> matchstring == (typ |> String.split(";") |> Enum.at(0)) end)
             |> Enum.any?
  end
end
