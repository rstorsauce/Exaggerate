defmodule Exaggerate do

  alias Exaggerate.Router

  @moduledoc """
  Swagger -> Plug DSL.

  this module also provides some macros which you can use
  in the case that you want to do something cute.
  """

  defmacro router(modulename, spec_json) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.

    routes = spec_json
    |> Jason.decode!
    |> Map.get("paths")
    |> Enum.flat_map(&unpack_route/1)

    rootpath = __CALLER__.module |> Module.split

    router = Module.concat(rootpath ++ [Macro.camelize(modulename <> "web"), Router])
    endpoint = Module.concat(rootpath ++ [Macro.camelize(modulename <> "web"), Endpoint])
    validator = Module.concat(rootpath ++ [Macro.camelize(modulename <> "web"), Validator])

    q = quote do
      defmodule unquote(router) do
        use Plug.Router

        alias unquote(endpoint)
        alias unquote(validator)

        plug :match
        plug :dispatch

        unquote_splicing(routes)
      end
    end
  end

  defp unpack_route({route, route_spec}) do
    Enum.map(route_spec, fn {verb, ep_spec} ->
      Router.route(
        {route, String.to_atom(verb)}, ep_spec)
    end)
  end

  def send_formatted(conn, code, response) do
    IO.puts("http send #{code}, with #{response}")
  end

end
