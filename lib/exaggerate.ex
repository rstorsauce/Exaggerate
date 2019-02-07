defmodule Exaggerate do

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

  @type error :: {:error, integer, String.t}


  defmacro router(modulename, spec_json) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.

    routes = spec_json
    |> Macro.expand(__CALLER__)
    |> Jason.decode!
    |> Map.get("paths")
    |> Enum.flat_map(&unpack_route(&1, Exaggerate.Router))

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

    IO.puts("==================")
    q |> Exaggerate.AST.to_string |> IO.puts

    q
  end

  defmacro validator(modulename, spec_json) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.

    validations = spec_json
    |> Macro.expand(__CALLER__)
    |> Jason.decode!
    |> Map.get("paths")
    |> Enum.flat_map(&unpack_route(&1, Exaggerate.Validator))

    rootpath = __CALLER__.module |> Module.split

    validator = Module.concat(rootpath ++ [Macro.camelize(modulename <> "_web"), Validator])

    q = quote do
      defmodule unquote(validator) do

        import Exonerate
        import Exaggerate

        unquote_splicing(validations)
      end
    end

    IO.puts("==================")
    q |> Exaggerate.AST.to_string |> IO.puts

    q
  end

  defp unpack_route({route, route_spec}, module) do
    Enum.map(route_spec, fn {verb, ep_spec} ->
      module.route({route, String.to_atom(verb)}, ep_spec)
    end)
  end

  def send_formatted(conn, code, response) do
    Plug.Conn.send_resp(conn, code, response)
  end

  defmacro defparam(method, true) do
    quote do
      @spec unquote(method)(Exonerate.json, true) :: :ok | Exaggerate.error
      def unquote(method)(content, true) do
        unquote(method)(content)
      end
    end
  end
  defmacro defparam(method, where, name) do
    quote do
      @spec unquote(method)(Exonerate.json, String.t) :: :ok | Exaggerate.error
      def unquote(method)(conn, name) do
        conn
        |> Map.get(where)
        |> Map.get(name)
        |> unquote(method)
      end
    end
  end

  defmacro defbodyparam([{method, mimetype}]) do
    quote do
      @spec unquote(method)(Exonerate.json, String.t, String.t) :: :ok | Exaggerate.error
      def unquote(method)(content, unquote(mimetype), unquote(mimetype)) do
        unquote(method)(content)
      end
      def unquote(method)(_, _, _) do
        :ok
      end
    end
  end

end
