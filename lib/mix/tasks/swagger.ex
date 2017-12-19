defmodule Mix.Tasks.Swagger do
  use Mix.Task

  @project_root File.cwd!

  @shortdoc "generates an api from the Exaggerate task"
  def run(swaggerfile) do
    swaggerfile |> Enum.map(&Exaggerate.Codesynth.build_fromfile/1)
  end

end
