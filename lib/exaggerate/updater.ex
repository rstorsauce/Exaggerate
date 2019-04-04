defmodule Exaggerate.Updater do

  alias Exaggerate.AST
  alias Exaggerate.Endpoint
  alias Exaggerate.Tools

  @spec update_router(String.t, String.t, String.t)::String.t
  def update_router(modulebase, code, json) do
    new_code = [header(modulebase), preamble(code), routes(json), postamble(code)]
    |> Enum.join("\n")
    |> Code.format_string!(locals_without_parens: [plug: :*])
    |> Enum.join

    new_code <> "\n"
  end

  @spec update_endpoint(String.t, String.t)::String.t
  def update_endpoint(code, json) do

    swagger_map = Jason.decode!(json)
    existing_calls = find_calls(code)

    new_code = swagger_map
    |> list_endpoints
    |> Enum.reject(&(&1 in existing_calls))
    |> Enum.map(&String.to_atom/1)
    |> Enum.map(&Endpoint.block(&1, %Endpoint{}))
    |> Enum.map(&AST.to_string/1)
    |> insert_into_ast(code)

    new_code <> "\n"
  end

  def generate_code(x), do: x

  ##########################################################
  ## ROUTER FUNCTIONS

  def header(modulebase) do

    mstring = modulebase
    |> Module.concat(:Router)
    |> inspect

    """
      defmodule #{mstring} do
        use Plug.Router

        alias Exaggerate.Tools
        alias Exaggerate.Responses
    """
  end

  ##########################################################
  ## ROUTER PREAMBLE AND PREAMBLE FUNCTIONS

  @doc """
  the preamble of an exaggerate route is all the first lines,
  except the initial defmodule and all of the critical use and
  alias phrases.  All lines that are not these phrases will
  be moved to after this regenerated section.  The end of the
  preamble is the first route.
  """
  @spec preamble(String.t) :: String.t
  def preamble(code) do
    code
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> drop_before_defmodule
    |> Enum.reject(&safe_preamble/1)
    |> Enum.take_while(&(not plug_route?(&1)))
    |> Enum.join("\n")
  end

  def drop_before_defmodule([]), do: []
  def drop_before_defmodule([head | rest]) do
    if String.starts_with?(head, "defmodule") do
      rest
    else
      drop_before_defmodule(rest)
    end
  end

  @safe_preamble_phrases ["use Plug.Router",
  "alias Exaggerate.Tools",
  "alias Exaggerate.Responses"]

  def safe_preamble(str) do
    str in @safe_preamble_phrases
  end

  @plug_routes ["delete", "get", "options", "patch", "post", "put"]

  def plug_route?(maybe_route) do
    Enum.any?(@plug_routes, &(String.starts_with?(maybe_route, &1)))
  end

  ##########################################################
  ## ROUTER POSTAMBLE AND POSTAMBLE FUNCTIONS

  @doc """
  the postamble is the collection of final "match" or "forward" routes.
  """
  def postamble(code) do
    code
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> parse_postamble
    |> Enum.join("\n")
  end

  @spec parse_postamble([String.t]) :: [String.t]
  def parse_postamble(lines), do: parse_postamble(lines, false, [])

  @spec parse_postamble([String.t], boolean, [String.t]) :: [String.t]
  defp parse_postamble([], _, postamble), do: Enum.reverse(postamble)
  defp parse_postamble([head | rest], true, so_far) do
    if plug_route?(head) do
      parse_postamble(rest, false, [])
    else
      parse_postamble(rest, true, [head | so_far])
    end
  end
  defp parse_postamble(["end" <> _ | rest], false, _so_far) do
    parse_postamble(rest, false, [])
  end
  defp parse_postamble([head | rest], false, so_far) do
    enter_protected? = String.starts_with?(head, "match") ||
    String.starts_with?(head, "forward")
    parse_postamble(rest, enter_protected?, [head | so_far])
  end

  ##########################################################
  ## ROUTER ROUTES FUNCTIONS

  @spec routes(String.t)::String.t
  def routes(swaggercode) do
    swaggercode
    |> Jason.decode!
    |> Map.get("paths")
    |> Enum.flat_map(&Tools.unpack_route(&1, Exaggerate.Router))
    |> Enum.map(&AST.to_string/1)
    |> Enum.join("\n")
  end

  ##########################################################
  ## ENDPOINT FUNCTIONS

  @spec find_calls(String.t)::[String.t]
  def find_calls(code) do
    code
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "def "))
    |> Enum.flat_map(fn line ->
      Regex.run(~r/def (\w[\w\d\_]*)/, line, capture: :all_but_first)
    end)
  end

  @spec list_endpoints(Exaggerate.spec_map)::[String.t]
  def list_endpoints(spec) do
    spec
    |> Map.get("paths")
    |> Enum.flat_map(&get_operations/1)
  end

  def get_operations({_, verb}) do
    Enum.flat_map(verb, fn
      {_k, %{"operationId" => op}} -> [op]
      _ -> []
    end)
  end

  def insert_into_ast(new_code, old_code) do
    old_code
    |> Code.format_string!
    |> List.insert_at(-2, new_code)
    |> Enum.join
    |> Code.format_string!
    |> Enum.join
  end
end
