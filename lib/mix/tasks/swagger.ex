defmodule Mix.Tasks.Swagger.Gen do
  use Mix.Task

  alias Exaggerate.AST
  alias Exaggerate.Router
  alias Exaggerate.Tools

  @shortdoc "generates an api from the supplied swaggerfile(s)"
  def run(params) do
    # do a really basic destructuring of the parameters
    [swaggerfile | _options] = params

    unless File.exists?(swaggerfile) do
      Mix.raise("No file error: can't find #{swaggerfile}")
    end

    basename = Path.basename(swaggerfile, ".json")

    # decode the swagger file into a an Elixir spec_map
    spec_map = swaggerfile
    |> Path.expand
    |> File.read!
    |> Jason.decode!

    # retrieve the app name.
    appname = Mix.Project.get()
    |> apply(:project, [])
    |> Keyword.get(:app)
    |> Atom.to_string

    # create the module path
    module_dir = Path.join([
      File.cwd!,
      "lib",
      appname,
      basename <> "_web"
    ])
    File.mkdir_p(module_dir)

    # build the endpoint file:
    module_code = (appname <> "." <> basename <> "_web")
    |> Tools.camelize
    |> Router.module(spec_map, swaggerfile)
    |> AST.to_string

    module_dir
    |> Path.join("router.ex")
    |> File.write!(module_code)
  end
end
