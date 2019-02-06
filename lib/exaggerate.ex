defmodule Exaggerate do

  alias Exaggerate.Router

  @moduledoc """
  Swagger -> Plug DSL.

  this module also provides some macros which you can use
  in the case that you want to do something cute.
  """

  @type spec_data :: float | integer | String.t
  | [spec_data] | %{optional(String.t) => spec_data}
  @typedoc """
  maps containing swagger spec information.
  """
  @type spec_map :: %{optional(String.t) => spec_data}

  @type http_verb :: :get | :post | :put | :patch |
                     :delete | :head | :options | :trace
  @type route :: {String.t, http_verb}

  defmacro router(modulename, spec_json) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.

    routes = spec_json
    |> Jason.decode!
    |> Map.get("paths")
    |> Enum.flat_map(&unpack_route/1)

    rootpath = __CALLER__.module |> Module.split

    router = Module.concat(rootpath ++ [Macro.camelize(modulename <> "_web"), :Router])
    endpoint = Module.concat(rootpath ++ [Macro.camelize(modulename <> "_web"), Endpoint])
    validator = Module.concat(rootpath ++ [Macro.camelize(modulename <> "_web"), Validator])

    q = quote do
      defmodule unquote(router) do
        use Plug.Router

        alias Exaggerate.Tools
        @endpoint unquote(endpoint)
        @validator unquote(validator)

        plug Plug.Parsers,
          parsers: [:urlencoded, :json, :multipart],
          pass: ["text/*"],
          json_decoder: Jason

        plug :match
        plug :dispatch

        unquote_splicing(routes)
      end
    end

    q |> Exaggerate.AST.to_string |> IO.puts

    q
  end

  defp unpack_route({route, route_spec}) do
    Enum.map(route_spec, fn {verb, ep_spec} ->
      Router.route(
        {route, String.to_atom(verb)}, ep_spec)
    end)
  end

  def send_formatted(conn, code, response) do
    Plug.Conn.send_resp(conn, code, response)
  end

end
