defmodule Exaggerate.AST do

  @type ast :: {atom, any, any}

  @spec to_string(ast) :: String.t
  def to_string(ast) do
    ast
    |> Macro.to_string(&ast_to_string/2)
    |> Code.format_string!
    |> IO.iodata_to_binary
    |> String.replace_suffix("", "\n")
  end

  # TODO: evaluate use of all of these conditions.
  @noparen [:defmodule, :use, :describe, :test, :defschema, :import, :assert, :def, :raise]
  # ast conversions
  # remove parentheses from :def, etc.
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
  # by default, leave the AST conversion untouched.
  def ast_to_string(_, any), do: any
end
