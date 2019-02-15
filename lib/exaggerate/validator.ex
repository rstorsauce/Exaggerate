defmodule Exaggerate.Validator do

  defstruct methods: []

  @type t :: %__MODULE__{methods: [Macro.t]}

  alias Exaggerate, as: E

  @spec route(E.route, E.spec_map) :: Macro.t
  def route({_path, _verb}, spec = %{"operationId" => id}) do
    parsed = %__MODULE__{}
    |> build_body(id, spec)
    |> build_param(id, spec)
    |> build_response(id, spec)

    splice_blocks(parsed.methods)
  end

  @spec build_body(t, String.t, E.spec_map) :: t
  def build_body(parser, id, %{"requestBody" => %{"content" => cmap}}) do
    parserlist = cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{mimetype, %{"schema" => smap}}, idx} ->
        generate_body_block(id <> "_content_" <> inspect(idx), smap, mimetype)
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
    |> Enum.map(fn {def = %{"schema" => smap}, idx} ->
        generate_parameter_block(id <> "_parameters_" <> inspect(idx),
          smap, def["required"])
      _ -> nil
    end)
    |> Enum.filter(&(&1))

    %__MODULE__{parser | methods: parser.methods ++ parserlist}
  end
  def build_param(parser, _, _), do: parser

  @spec build_response(t, String.t, E.spec_map) :: t
  def build_response(parser, id, %{"responses" => rmap}) do

    # check if there's one response validator necessary or
    # more than one response validator necessary

    ss = single_success_code?(rmap)

    parserlist =
      Enum.flat_map(rmap, &build_response_route(&1, id, ss))

    %__MODULE__{parser | methods: parser.methods ++ parserlist}
  end
  def build_response(parser, _, _), do: parser

  @spec single_success_code?(E.spec_map) :: boolean
  defp single_success_code?(rmap) do
    rmap |> IO.inspect(label: "66")
    1 == (Enum.count(rmap, fn
      {k, v} -> String.to_integer(k) < 300 && has_schema?(v)
    end) |> IO.inspect(label: "68"))
  end

  @spec has_schema?(E.spec_map) :: boolean
  defp has_schema?(%{"content" => cmap}) do
    Enum.any?(cmap, fn {_k, v} -> Map.has_key?(v, "schema") end)
  end
  defp has_schema?(_), do: false

  @spec build_response_route({String.t, E.spec_map},
                             String.t,
                             boolean | String.t)::[Macro.t]
  def build_response_route({resp_code, %{"content" => cmap}}, id, ss) do
    cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{_k, %{"schema" => schema}}, idx} ->
        [id, "response", resp_code, idx]
        |> Enum.join("_")
        |> generate_response_block(schema, id, ss || resp_code)
      _ -> nil
    end)
    |> Enum.filter(&(&1))
  end
  def build_response_route(_, _, _), do: []

  @spec generate_response_block(String.t, E.spec_map, String.t, boolean | String.t) :: Macro.t
  def generate_response_block(label, spec, id, true) do
    id_atom = String.to_atom(id <> "_response")
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    schema = {:defschema, [], [[{label_atom, spec_str}]]}

    quote do
      if Mix.env in [:dev, :test] do

        def unquote(id_atom)({:ok, resp}) do
          unquote(label_atom)(resp)
        end
        def unquote(id_atom)(_) do
          :ok
        end

        unquote(schema)

      else
        def unquote(id_atom)(_) do
          :ok
        end
      end
    end
  end
  def generate_response_block(label, spec, id, _) do
    quote do nil end
  end

  @spec generate_body_block(String.t, E.spec_map, String.t) :: Macro.t
  def generate_body_block(label, spec, mimetype) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    schema = {:defschema, [], [[{label_atom, spec_str}]]}

    quote do
      @spec unquote(label_atom)(Exonerate.json, String.t, String.t) :: :ok | Exaggerate.error
      def unquote(label_atom)(content, unquote(mimetype), unquote(mimetype)) do
        unquote(label_atom)(content)
      end
      def unquote(label_atom)(_, _, _) do
        :ok
      end
      unquote(schema)
    end
  end

  @spec generate_parameter_block(String.t, E.spec_map, boolean) :: Macro.t
  @doc """
  generates a validation block for a particular test, based on the
  `parameter` archetype.  This is a trampoline, if it's optional,
  followed by a defschema statement (pulling from exonerate).
  """
  def generate_parameter_block(label, spec, required) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> ensigil

    schema = {:defschema, [], [[{label_atom, spec_str}]]}

    if required do
      schema
    else
      trampoline = String.to_atom(label <> "_trampoline")
      quote do
        @spec unquote(trampoline)(Exonerate.json) :: :ok | Exaggerate.error
        def unquote(trampoline)(content) do
          if is_nil(content) do
            :ok
          else
            unquote(label_atom)(content)
          end
        end
        unquote(schema)
      end
    end
  end

  @spec ensigil(String.t) :: Macro.t
  defp ensigil(string) do
    {:sigil_s,
      [context: Elixir, import: Kernel],
      [{:<<>>, [], [string]}, []]}
  end

  @spec splice_blocks([Macro.t]) :: Macro.t
  def splice_blocks(blocklist) do
    {:__block__, [],
      Enum.flat_map(blocklist, fn
        {:__block__, [], list} -> list
        any -> [any]
      end)
    }
  end

end
