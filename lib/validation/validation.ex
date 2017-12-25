defmodule Exaggerate.Validation do

  @project_root Exaggerate.get_project_root()

  require Logger

  @doc """
    tests if an array has any duplicates, in which case, the first found one is reported.
    otherwise returns nil.

    # Examples

    iex> Exaggerate.Validation.duplicates([1,2,3,4])      #==>
    nil

    iex> Exaggerate.Validation.duplicates([1,2,2,3,4])    #==>
    2

    iex> Exaggerate.Validation.duplicates([1,2,3,4,4,2])  #==>
    2
  """
  def duplicates([head | tail]), do: duplicates(tail, tail, head)
  def duplicates([], _, _), do: nil
  def duplicates([statehead | statetail], [], _), do: duplicates(statetail, statetail, statehead)
  def duplicates(_state, [head | _tail], head), do: head
  def duplicates(state, [_head | tail], check), do: duplicates(state, tail, check)

  @doc """
    searches an array of error/ok responses and falls through if
    there's any error; but ok's if none are found.
  """
  def error_search([]), do: :ok
  def error_search([:ok | tail]), do: error_search(tail)
  def error_search([error | _tail]), do: error

  def validation_or(:ok, _, _error), do: :ok
  def validation_or(_, :ok, _error), do: :ok
  def validation_or(_,_, error), do: error

  def validate!(swaggerfile) do

    Application.ensure_all_started(:yaml_elixir)

    @project_root
      |> Path.join(swaggerfile)
      |> File.read!
      |> Poison.decode!
      |> Exaggerate.Validation.OpenAPI.validate
      |> fn :ok -> :ok
            {:error, mod, desc} -> Logger.error("#{desc} in module #{inspect mod}")
         end.()
  end
end
