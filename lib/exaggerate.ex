defmodule Exaggerate do
  # NB: this is kind of a very lame way of doing this.  A way of autodetecting
  # if a library is in a context would be MUCH better.
  def get_project_root do
    case File.cwd! |> Path.split |> Enum.at(-2) do
      "deps" -> Path.relative_to_cwd("../../") |> Path.expand
      _ -> File.cwd!
    end
  end

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
