defmodule Exaggerate.Router do

  alias Exaggerate.AST
  alias Exaggerate.Tools
  alias Exaggerate, as: E

  defstruct vars: [],
            guards: [],
            elses: [],
            fetches: MapSet.new([])

  @type t :: %__MODULE__{
    vars:    [String.t],
    guards:  [AST.leftarrow],
    elses:   [AST.rightarrow],
    fetches: MapSet.t(Macro.t)
  }

  # OpenAPI 3.0 supports the following verbs for operations:
  # https://swagger.io/docs/specification/paths-and-operations/#operations

  @spec route(E.route, E.spec_map) :: Macro.t
  def route({path!, verb}, spec) do
    do_block = %__MODULE__{}
    |> build_body(spec)
    |> build_params(spec)
    |> validate_body(spec)
    |> validate_params(spec)
    |> add_typecheck(spec)
    |> add_mimecheck(spec)
    |> finalize(spec)
    |> assemble(spec)

    path! = AST.swagger_to_sinatra(path!)

    {verb, [], [path!, [do: do_block]]}
  end

  defp build_summary(list, nil), do: list
  defp build_summary(list, summary) do
    list ++ [quote do
      @comment unquote(summary)
    end]
  end

  @spec build_body(t, E.spec_map) :: t
  defp build_body(parser, spec = %{"requestBody" => rq_map}) do
    if rq_map["content"] do
      mimetype_list = Map.keys(rq_map["content"])

      parser
      |> push_var("content")
      |> push_guard(quote do
        {:ok, content_type} <- Tools.match_mimetype(var!(conn), unquote(mimetype_list))
      end)
      |> push_guard(quote do
        {:ok, var!(content)} <- Tools.get_body(var!(conn))
      end)
      |> build_params(Map.delete(spec, "requestBody"))
    else
      parser
    end
  end
  defp build_body(parser, _), do: parser

  @spec build_params(t, E.spec_map) :: t
  defp build_params(parser, %{"parameters" => params}) do
    Enum.reduce(params, parser, &build_param/2)
  end
  defp build_params(parser, _), do: parser

  @jsonschema_types ["integer", "string", "object", "array", "number", "boolean", "null"]

  @spec fetcher(String.t) :: atom
  # generates a fetcher symbol that lives in the Exonerate.Tools module.
  defp fetcher(location), do: String.to_atom("get_" <> location)

  @spec prefetch(String.t) :: Macro.t
  defp prefetch("cookie") do
    quote do conn = Plug.Conn.fetch_req_cookies(conn) end
  end
  defp prefetch("query") do
    quote do conn = Plug.Conn.fetch_query_params(conn) end
  end
  defp prefetch(_), do:  nil

  @spec names_for(String.t, String.t) :: {String.t, String.t}
  # canonicalizes names to an elixir reasonable symbols.
  defp names_for(name, "header") do
    {name
    |> String.replace("-", "_")
    |> String.downcase,
    name}
  end
  defp names_for(name, _) do
    snake = Macro.underscore(name)
    {snake, snake}
  end

  defp build_param(%{"in" => location,
                     "required" => true,
                     "name" => name,
                     "schema" => %{"type" => type}}, parser)
                     when type in @jsonschema_types do
    prefetch_fn = prefetch(location)
    fetch_fn = fetcher(location)
    {var_name, fetch_name} = names_for(name, location)
    name_ast = AST.var_ast(var_name)
    type_atom = String.to_atom(type)
    parser
    |> push_fetch(prefetch_fn)
    |> push_var(var_name)
    |> push_guard(quote do
      {:ok, unquote(name_ast)}
        <- Tools.unquote(fetch_fn)(var!(conn), unquote(fetch_name), unquote(type_atom))
    end)
  end
  defp build_param(%{"in" => location,
                     "required" => true,
                     "name" => name}, parser) do
    prefetch_fn = prefetch(location)
    fetch_fn = fetcher(location)
    {var_name, fetch_name} = names_for(name, location)
    name_ast = AST.var_ast(var_name)
    parser
    |> push_fetch(prefetch_fn)
    |> push_var(var_name)
    |> push_guard(quote do
      {:ok, unquote(name_ast)} <- Tools.unquote(fetch_fn)(var!(conn), unquote(fetch_name))
    end)
  end
  defp build_param(%{"in" => location,
                     "required" => false,
                     "name" => name,
                     "schema" => schema}, parser) do
    parser
  end
  defp build_param(_, parser) do
    parser
  end

  defp validator(id, type, idx, suffix \\ []) do
    [id, type, inspect(idx)] ++ suffix
    |> Enum.join("_")
    |> String.to_atom
  end

  @spec validate_body(t, E.spec_map) :: t
  defp validate_body(parser, %{"operationId" => id,
                               "requestBody" => %{"content" => cmap}}) do
    cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{mime_type, %{"schema" => _}}, idx} ->
        method = validator(id, "content", idx)
        quote do
          :ok <- @validator.unquote(method)(var!(content), content_type, unquote(mime_type))
        end
      _ -> nil
    end)
    |> Enum.filter(&(&1))
    |> Enum.reduce(parser, &push_guard(&2, &1))
  end
  defp validate_body(parser, _), do: parser

  # TODO: move router parameter fetches into their own piece at
  # the start.

  @spec validate_params(t, E.spec_map) :: t
  defp validate_params(parser, %{"operationId" => id,
                               "parameters" => plist}) do
    plist
    |> Enum.with_index
    |> Enum.map(&validate_param(&1, id))
    |> Enum.filter(&(&1))
    |> Enum.reduce(parser, &push_guard(&2, &1))
  end
  defp validate_params(parser, _), do: parser

  @simple_schemata [
    %{"type" => "integer"},
    %{"type" => "number"},
    %{"type" => "string"},
    true,
    false,
    %{}
  ]

  defp validate_param({%{"in" => _,
                         "name" => _,
                         "schema" => s}, _}, _) when
                         s in @simple_schemata, do: nil
  defp validate_param({%{"in" => location,
                         "name" => name,
                         "required" => true,
                         "schema" => _}, idx}, id) do

    method = validator(id, "parameters", idx)
    {var_name, _} = names_for(name, location)
    name_ast = AST.var_ast(var_name)

    quote do
      :ok <- @validator.unquote(method)(unquote(name_ast))
    end
  end
  defp validate_param({%{"in" => _location,
                         "name" => name,
                         "schema" => _}, idx}, id) do
    method = validator(id, "parameters", idx, ["trampoline"])
    quote do
      :ok <- @validator.unquote(method)(var!(conn).query_params[unquote(name)])
    end
  end
  defp validate_param(_, _), do: nil

  defp resp_needs_validation?(%{"responses" => rmap}) do
    Enum.any?(rmap, fn {_code, cmap} -> code_needs_validation?(cmap) end)
  end
  defp resp_needs_validation?(_), do: false
  defp code_needs_validation?(%{"content" => cmap}) do
    Enum.any?(cmap, fn {_k, v} -> Map.has_key?(v, "schema") end)
  end
  defp code_needs_validation?(_), do: false

  @spec finalize(t, E.spec_map) :: t
  defp finalize(parser, spec = %{"operationId" => id}) do
    call = AST.generate_call(id, parser.vars)
    |> maybe_validate_response(id, spec)

    spec
    |> success_code
    |> case do
      :multi ->
        push_guard(parser, quote do
          {:ok, code, response} <- unquote(call)
        end)
      _ ->
        parser
        |> push_guard(quote do
          {:ok, response} <- unquote(call)
        end)
        |> push_else(quote do
          {:ok, code, response} ->
            Responses.send_formatted(var!(conn), code, response)
        end)
    end
    |> push_else(quote do
      {:error, ecode, response} ->
        Responses.send_formatted(var!(conn), ecode, response)
    end)
  end

  defp maybe_validate_response(stmt, id, spec) do
    if resp_needs_validation?(spec) do
      validation = [id, "response"]
      |> Enum.join("_")
      |> String.to_atom

      quote do
        @validator.unquote(validation)(unquote(stmt))
      end
    else
      stmt
    end
  end

  # PUSH FUNCTIONS

  @spec push_var(t, String.t) :: t
  defp push_var(parser, str) do
    %__MODULE__{parser | vars: parser.vars ++ [str]}
  end

  @spec push_guard(t, AST.leftarrow) :: t
  defp push_guard(parser, ast) do
    %__MODULE__{parser | guards: parser.guards ++ [ast]}
  end

  @spec push_else(t, AST.rightarrow) :: t
  defp push_else(parser, ast) do
    %__MODULE__{parser | elses: parser.elses ++ [ast]}
  end

  @spec push_fetch(t, Macro.t | nil) :: t
  defp push_fetch(parser, nil), do: parser
  defp push_fetch(parser, ast) do
    %__MODULE__{parser | fetches: MapSet.put(parser.fetches, ast)}
  end

  @spec assemble(t, E.spec_map) :: Macro.t
  defp assemble(parser, spec) do

    code = spec
    |> success_code
    |> case do
      :multi -> {:code, [], Elixir}
      any -> any
    end

    with_ast = AST.generate_with(
      parser.guards,
      quote do Responses.send_formatted(var!(conn), unquote(code), response) end,
      parser.elses
    )

    if spec["summary"] do
      quote do
        @comment unquote(spec["summary"])
        unquote_splicing(Enum.to_list(parser.fetches))
        unquote(with_ast)
      end
    else
      with_ast
    end
  end

  @spec success_code(E.spec_map) :: :multi | integer
  def success_code(%{"responses" => rmap}) do
    cond do
      Map.has_key?(rmap, "1XX") -> :multi
      Map.has_key?(rmap, "2XX") -> :multi
      true ->
        list = rmap
        |> Map.keys
        |> Enum.map(&String.to_integer/1)
        |> Enum.filter(&(&1 < 300))
        successes = Enum.count(list)

        cond do
          successes == 0 -> 200
          successes == 1 -> Enum.at(list, 0)
          true -> :multi
        end
    end
  end
  # http code 200 is a default response code.
  def success_code(_spec), do: 200

  @spec add_typecheck(t, E.spec_map) :: t
  defp add_typecheck(parser, spec) do
    if needs_typecheck?(spec) do
      push_else(parser, quote do
        {:mismatch, {loc, val}} ->
          Responses.send_formatted(var!(conn), 400, "invalid parameter value")
      end)
    else
      parser
    end
  end

  @spec needs_typecheck?(E.spec_map) :: boolean
  def needs_typecheck?(path) do
    params_needs_check?(path["parameters"]) ||
    body_needs_check?(path["requestBody"])
  end

  @spec params_needs_check?(nil | []) :: boolean
  defp params_needs_check?(nil), do: false
  defp params_needs_check?([]), do: false
  defp params_needs_check?(arr) do
    Enum.any?(arr, fn
      %{"schema" => schema} when schema not in @simple_schemata -> true
      %{} -> false
    end)
  end

  @spec body_needs_check?(nil | []) :: boolean
  defp body_needs_check?(nil), do: false
  defp body_needs_check?(%{"content" => content}) do
    Enum.any?(content, fn
      {_, %{"schema" => schema}}  when schema not in @simple_schemata -> true
      {_, _} -> false
    end)
  end
  defp body_needs_check?(_), do: false

  @spec add_mimecheck(t, E.spec_map) :: t
  defp add_mimecheck(parser, spec) do
    if needs_mimecheck?(spec) do
      push_else(parser, quote do
        {:error, :mimetype} ->
          Responses.send_formatted(var!(conn), 400, "invalid request Content-Type")
      end)
    else
      parser
    end
  end

  @spec needs_mimecheck?(E.spec_map) :: boolean
  defp needs_mimecheck?(%{"requestBody" => _}), do: true
  defp needs_mimecheck?(_), do: false

  @spec module(atom | binary, E.spec_map) :: Macro.t
  def module(moduleroot, spec), do: module(moduleroot, spec, "test.json")

  @spec module(atom | binary, E.spec_map, Path.t) :: Macro.t
  def module(moduleroot, spec, filename) do

    routes = spec
    |> Map.get("paths")
    |> Enum.flat_map(&Exaggerate.Tools.unpack_route(&1, Exaggerate.Router))

    router = Module.concat(moduleroot, :Router)
    endpoint = Module.concat(moduleroot, :Endpoint)
    validator = Module.concat(moduleroot, :Validator)

    quote do
      defmodule unquote(router) do
        use Plug.Router

        alias Exaggerate.Tools
        alias Exaggerate.Responses

        plug :match

        plug Plug.Parsers,
          parsers: [:urlencoded, :json, :multipart],
          pass: ["*/*"],
          json_decoder: Jason

        plug :dispatch

        @comment ""
        @comment "      --WARNING--"
        @comment ""
        @comment "the following module parameters are set for convenience.  Please"
        @comment "do not change them, unless you are spoofing them for mocking"
        @comment "purposes."
        @comment ""
        @comment ""

        @blankline _

        @endpoint unquote(endpoint)
        @validator unquote(validator)

        @blankline _

        @comment ""
        @comment "      --WARNING--"
        @comment ""
        @comment "routing code below this point is autogenerated.  Alterations to this code"
        @comment "risk introducing deviations to the supplied OpenAPI specification. Please"
        @comment unquote("consider modifying `#{filename}` instead of this file, followed by")
        @comment ""
        @comment unquote("    `mix swagger.update #{filename}`")
        @comment ""
        @comment ""

        @blankline _

        unquote_splicing(routes)

        match _ do
          send_resp(var!(conn), 404, "")
        end
      end
    end
  end

  @doc """
  generates a router module as a submodule of the current module.

      defmodule Module do
        router my_schema: ~s(<json-string>)
      end

  creates the following module:

      defmodule Module.MySchemaWeb.Router do
        ...
        <validation code>
        ...
      end

  Mostly useful for testing.  Note that the main module does NOT use this function
  but calls module() instead.
  """
  defmacro router(modulename, spec_json) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.

    spec_map = spec_json
    |> Macro.expand(__CALLER__)
    |> Jason.decode!

    __CALLER__.module
    |> Module.concat(Tools.camelize(modulename <> "_web"))
    |> module(spec_map)
    |> AST.decomment
  end

end
