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
    |> Code.format_string!(locals_without_parens: [defschema: 1, plug: :*])
    |> IO.iodata_to_binary
    |> String.replace_suffix("", "\n")
  end

  @openapi_verbs [:get, :post, :put, :patch,
                  :delete, :head, :options, :trace]
  @noparen_simple [:use, :describe, :test,
                   :defschema, :import, :assert,
                   :raise, :plug, :alias]
  @noparen_header [:defmodule, :def, :with] ++ @openapi_verbs
  @noparen_dot [:body_params]
  # ast conversions
  # remove parentheses from :def, etc.
  @spec ast_to_string(Macro.t, String.t)::String.t
  def ast_to_string({atom, _, _}, str) when atom in @noparen_simple do
    symbol = Atom.to_string(atom)
    str
    |> String.replace_leading(symbol <> "(", symbol <> " ")
    |> String.trim_trailing
    |> String.replace_suffix(")", "\n")
  end
  def ast_to_string({atom, _, _}, str) when atom in @noparen_header do
    [head | rest] = String.split(str, "\n")
    symbol = Atom.to_string(atom)
    new_head = head
    |> String.replace_leading(symbol <> "(", symbol <> " ")
    |> String.trim_trailing
    |> String.replace_suffix(") do", " do")
    Enum.join([new_head | rest], "\n")
  end
  # trap var! macros as stripping their contents.
  def ast_to_string({:var!, _, [{varname, _, _}]}, _) do
    "#{varname}"
  end
  # trap @comment bits as actual comments.  Empty comments get no space.
  def ast_to_string({:@, _, [{:comment, _, [""]}]}, _) do
    "#"
  end
  def ast_to_string({:@, _, [{:comment, _, comment}]}, _) do
    "# #{comment}"
  end
  # trap sigil_s using the parenthesis mode do
  def ast_to_string({:sigil_s, _, [{:<<>>, _, [string]} | _]}, _) do
    trimmed = String.trim(string)
    if String.contains?(trimmed, "\n") do
      "\"\"\"\n#{trimmed}\n\"\"\""
    else
      "\"#{trimmed}\""
    end
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

  @endpoint {:@, [context: Elixir, import: Kernel],
               [{:endpoint, [context: Elixir], Elixir}]}
  @conn {:var!, [context: Elixir, import: Kernel], [{:conn, [], Elixir}]}
  @content {:var!, [context: Elixir, import: Kernel], [{:content, [], Elixir}]}

  @spec generate_call(String.t, [String.t])::Macro.t
  def generate_call(method, ["content" | rest]) do
    {
      {:., [], [@endpoint, String.to_atom(method)]},
      [],
      [@conn, @content] ++
      (rest
      |> Enum.map(&Macro.underscore/1)
      |> Enum.map(&String.to_atom/1)
      |> Enum.map(fn p -> {p, [], Elixir} end))
    }
  end
  def generate_call(method, parameters) do
    {
      {:., [], [@endpoint, String.to_atom(method)]},
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
