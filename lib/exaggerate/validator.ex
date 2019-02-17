defmodule Exaggerate.Validator do

  defstruct methods: []

  @type t :: %__MODULE__{methods: [Macro.t]}

  alias Exaggerate, as: E
  alias Exaggerate.AST

  @spec route(E.route, E.spec_map) :: Macro.t
  def route({_path, _verb}, spec = %{"operationId" => id}) do
    parsed = %__MODULE__{}
    |> build_body(id, spec)
    |> build_param(id, spec)
    |> build_response(id, spec)

    AST.splice_blocks(parsed.methods)
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
    case Exaggerate.Validator.Response.block(id, rmap) do
      block ->
        %__MODULE__{parser | methods: parser.methods ++ [block]}
      nil ->
        parser
    end
  end
  def build_response(parser, _, _), do: parser

  @spec generate_body_block(String.t, E.spec_map, String.t) :: Macro.t
  def generate_body_block(label, spec, mimetype) do
    label_atom = String.to_atom(label)
    spec_str = spec
    |> Jason.encode!(pretty: true)
    |> AST.ensigil

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
    |> AST.ensigil

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

end
