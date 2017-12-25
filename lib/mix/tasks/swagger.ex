defmodule Mix.Tasks.Swagger do
  use Mix.Task

  @shortdoc "generates an api from the supplied swaggerfile(s)"
  def run(swaggerfile) do

    swaggerfile |> Enum.map(&Exaggerate.Validation.validate!/1)

    swaggerfile |> Enum.map(&Exaggerate.Codesynth.buildswaggerfile/1)
  end
end

defmodule Mix.Tasks.Swagger.Update do
  use Mix.Task

  @shortdoc "updates an api from the supplied swaggerfile(s)"
  def run(swaggerfile) do
    swaggerfile |> Enum.map(&Exaggerate.Codesynth.updateswaggerfile/1)
  end
end
