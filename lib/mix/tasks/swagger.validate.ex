defmodule Mix.Tasks.Swagger.Validate do
  use Mix.Task

  @shortdoc "updates an api from the supplied swaggerfile(s)"
  def run(swaggerfile) do
  #  swaggerfile |> Enum.map(fn f -> {f, Exaggerate.Validation.validate!(f)} end)
  #              |> Enum.map(fn {f, :ok} -> :ok
  #                             {f, {:error, mod, desc}} -> raise("error in file #{f}; #{inspect mod}: desc") end)
  end
end
