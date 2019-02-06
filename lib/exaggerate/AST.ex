defmodule Exaggerate.AST do

  @type context :: [any]
  @type defmod  :: {:defmodule, context, [any]}
  @type def     :: {:def, context, [any]}
  @type comment :: {:@, context, {:comment, context, [String.t]}}
  @type block   :: {:__block__, context, [Macro.t]}

  @type rightarrow :: [{:->, context, [Macro.t, ...]}]
  @type leftarrow  :: {:<-, context, [Macro.t, ...]}

  @spec to_string(Macro.t) :: String.t
  def to_string(ast) do
    ast
    |> Macro.to_string(&ast_to_string/2)
    |> Code.format_string!
    |> IO.iodata_to_binary
    |> String.replace_suffix("", "\n")
  end

  @openapi_verbs [:get, :post, :put, :patch,
                  :delete, :head, :options, :trace]
  @noparen [:defmodule, :use, :describe, :test, :defschema, :import, :assert, :def,
            :raise, :with] ++ @openapi_verbs
  @noparen_dot [:body_params]
  # ast conversions
  # remove parentheses from :def, etc.
  @spec ast_to_string(Macro.t, String.t)::String.t
  def ast_to_string({atom, _, _}, str) when atom in @noparen do
    [head | rest] = String.split(str, "\n")
    parts = Regex.named_captures(~r/\((?<title>.*)\)(?<rest>.*)/, head)

    Atom.to_string(atom) <>
    " " <> parts["title"] <>
    parts["rest"] <> "\n" <> Enum.join(rest, "\n")
  end
  # trap @comment bits as actual comments.  Empty comments get no space.
  def ast_to_string({:@, _, [{:comment, _, [""]}]}, _) do
    "#"
  end
  def ast_to_string({:@, _, [{:comment, _, comment}]}, _) do
    "# #{comment}"
  end
  def ast_to_string({{:., _, [_, param]}, _, _}, str)
    when param in @noparen_dot do
    String.trim_trailing(str, "()")
  end
  # by default, leave the AST conversion untouched.
  def ast_to_string(_, any), do: any

  @doc """
    generate a with clause from a set of ast pairs.
    a trivial with clause gives case
  """
  def generate_with(clause_list, coda, else_list \\ [])
  def generate_with([], coda, _else_list), do: coda
  def generate_with(clause_list, coda, else_list) do
    {:with, [],
      clause_list ++
      [[do: coda] ++
      if else_list == [] do
        []
      else
        [else: Enum.flat_map(else_list, &(&1))]
      end]
    }
  end

  @conn {:var!, [context: Elixir, import: Kernel], [{:conn, [], Elixir}]}

  @spec generate_call(atom, String.t, [String.t])::Macro.t
  def generate_call(module, method, parameters) do
    {
      {:., [], [module, String.to_atom(method)]},
      [],
      [@conn] ++
      (parameters
      |> Enum.map(&Macro.underscore/1)
      |> Enum.map(&String.to_atom/1)
      |> Enum.map(fn p -> {p, [], Elixir} end))
    }
  end

  @spec var_ast(String.t) :: {atom, [], Elixir}
  def var_ast(var) do
    { String.to_atom(var), [], Elixir }
  end

  @spec swagger_to_sinatra(String.t)::String.t
  def swagger_to_sinatra(v) do
    Regex.replace(~r/\{([a-zA-Z0-9]+)\}/, v,
      fn _, x -> ":" <> Macro.underscore(x) end)
  end

  @spec decomment(Macro.t) :: Macro.t
  @doc """
  a tool for stripping @comments from elixir ASTs.
  """
  def decomment({any, context, content}) do
    {any, context, decomment(content)}
  end
  def decomment({any, content}) do
    {any, decomment(content)}
  end
  def decomment(content) when is_list(content) do
    content
    |> Enum.reject(&comment?/1)
    |> Enum.map(&decomment/1)
  end
  def decomment(any), do: any

  @spec comment?(Macro.t)::boolean
  defp comment?({:@, _, [{:comment, _, _}]}), do: true
  defp comment?(_val), do: false
end
