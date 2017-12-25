defmodule Exaggerate do
  # NB: this is kind of a very lame way of doing this.  A way of autodetecting 
  # if a library is in a context would be MUCH better.
  def get_project_root do
    case File.cwd! |> Path.split |> Enum.at(-2) do
      "deps" -> Path.relative_to_cwd("../../") |> Path.expand
      _ -> File.cwd!
    end
  end
end
