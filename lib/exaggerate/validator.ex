defmodule Exaggerate.Validator do

  defstruct methods: []

  @type t :: %__MODULE__{methods: [Macro.t]}

  alias Exaggerate, as: E

  @spec route(E.route, E.spec_map) :: Macro.t
  def route({_path, _verb}, spec = %{"operationId" => id}) do
    parsed = %__MODULE__{}
    |> build_body(id, spec)
    |> build_param(id, spec)

    splice_blocks(parsed.methods)
  end

  @spec build_body(t, String.t, E.spec_map) :: t
  def build_body(parser, id, %{"requestBody" => %{"content" => cmap}}) do
    parserlist = cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{mimetype, %{"schema" => smap}}, idx} ->
        generate_defschema(id <> "_body_" <> inspect(idx), smap, mimetype)
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

  @spec generate_defschema(String.t, E.spec_map, String.t) :: Macro.t
  def generate_defschema(label, spec, mimetype) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    bodyparam = {:defbodyparam, [], [[{label_atom, mimetype}]]}
    schema = {:defschema, [], [[{label_atom, spec_str}]]}

    quote do
      unquote(bodyparam)
      unquote(schema)
    end
  end

  @spec generate_defschema(String.t, E.spec_map) :: Macro.t
  def generate_defschema(label, spec) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    {:defparam, [], [[label_atom]]}
    {:defschema, [], [[{label_atom, spec_str}]]}
  end

  @spec ensigil(String.t) :: Macro.t
  defp ensigil(string) do
    {:sigil_s,
      [context: Elixir, import: Kernel],
      [{:<<>>, [], [string]}, []]}
  end

  @spec splice_blocks([Macro.t]) :: Macro.t
  defp splice_blocks(blocklist) do
    {:__block__, [],
      Enum.flat_map(blocklist, fn
        {:__block__, [], list} -> list
        any -> [any]
      end)
    }
  end

end
