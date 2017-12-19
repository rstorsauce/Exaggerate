defmodule Mix.Tasks.Swagger do
  use Mix.Task

  @project_root File.cwd!

  @shortdoc "generates an api from the Exaggerate task"
  def run(swaggerfile) do
    Exaggerate.Codesynth.build_fromfile(swaggerfile)
  end

end
