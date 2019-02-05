defmodule Exaggerate.AST do

  @type context :: [any]
  @type ast     :: {atom, context, [any]}
  @type defmod  :: {:defmodule, context, [any]}
  @type def     :: {:def, context, [any]}
  @type comment :: {:@, context, {:comment, context, [String.t]}}
  @type block   :: {:__block__, context, [ast]}

  @spec to_string(ast) :: String.t
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
  @spec ast_to_string(ast, String.t)::String.t
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
  """
  def generate_with(clause_list, coda, else_list \\ nil) do
    {:with, [],
      clause_list ++
      [[do: coda] ++
      if else_list do
        [else: Enum.flat_map(else_list, &(&1))]
      else
        []
      end]
    }
  end
end
