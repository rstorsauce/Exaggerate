defmodule Exaggerate.Validator do

  defstruct methods: []

  @type t :: %__MODULE__{methods: [Macro.t]}

  alias Exaggerate, as: E

  @spec route(E.route, E.spec_map) :: Macro.t
  def route({_path, _verb}, spec = %{"operationId" => id}) do
    parsed = %__MODULE__{}
    |> build_body(id, spec)
    |> build_param(id, spec)

    quote do
      unquote_splicing(parsed.methods)
    end
  end

  @spec build_body(t, String.t, E.spec_map) :: t
  def build_body(parser, id, %{"requestBody" => %{"content" => cmap}}) do
    parserlist = cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{_mime_type, %{"schema" => smap}}, idx} ->
        generate_defschema(id <> "_body_" <> inspect(idx), smap)
      _ -> nil
    end)
    |> Enum.filter(&(&1))

    %__MODULE__{parser | methods: parser.methods ++ parserlist}
  end
  def build_body(parser, _, _), do: parser

  @spec build_param(t, String.t, E.spec_map) :: t
  def build_param(parser, id, %{"parameters" => pmap}) do
    parserlist = pmap
    |> Enum.with_index
    |> Enum.map(fn {%{"schema" => smap}, idx} ->
        generate_defschema(id <> "_parameters_" <> inspect(idx), smap)
      _ -> nil
    end)
    |> Enum.filter(&(&1))

    %__MODULE__{parser | methods: parser.methods ++ parserlist}
  end
  def build_param(parser, _, _), do: parser

  def generate_defschema(label, spec) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    {:defschema, [], [[{label_atom, spec_str}]]}
  end

  defp ensigil(string) do
    {:sigil_s,
      [context: Elixir, import: Kernel],
      [{:<<>>, [], [string]}, []]}
  end
end
