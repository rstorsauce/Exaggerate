defmodule Exaggerate.Validator.Response do
  @moduledoc """
  the response validator is complicated enough that it needs its own parser.

  for that reason, it's put into its own module.
  """

  defstruct trampolines: [],
            schemata: []

  @type t()::%__MODULE__{
    trampolines: [Macro.t],
    schemata: [Macro.t]
  }

  alias Exaggerate, as: E
  alias Exaggerate.AST

  @doc """
    takes a "response" value map, and converts it to an abstract
    syntax tree that represents the relevant parser map.
  """
  @spec block(String.t, E.spec_map) :: Macro.t | nil
  def block(id, spec_map) do
    resp_id = Enum.join([id, "response"], "_")

    # the swagger spec has a very complicated scheme for determining which
    # jsonschemata apply in the context of specs.  Let's simplify that a bit
    # and in the process omit all branches that need to be checked.

    simple_spec = simplify_spec(spec_map)

    %__MODULE__{}
    |> add_trampolines(resp_id, simple_spec)
    |> add_final_trampoline(resp_id)
    |> add_schemata(resp_id, simple_spec)
    |> finalize(resp_id)
  end

  #############################################################################
  ## schema simplification.

  @typedoc """
  a map that allows for consistency in mimetype/integer associations.  Map key
  is a tuple with number represting index, and string, value is JSONschema.
  """
  @type type_map :: %{optional({non_neg_integer, String.t}) => Exonerate.json}

  @typedoc """
  assigns a mimetype => schema map to a status typecode.
  """
  @type simple_spec :: %{optional(non_neg_integer) => type_map}

  @spec simplify_spec(E.spec_map) :: simple_spec
  defp simplify_spec(specmap) do
    specmap
    |> Enum.map(&simplify_code_spec/1)
    |> Enum.into(%{})
  end

  @spec simplify_code_spec({String.t, E.spec_map}) :: {non_neg_integer, type_map}
  defp simplify_code_spec({http_code, %{"content" => cmap}}) do
    simplified_map = cmap
    |> Enum.with_index
    |> Enum.map(fn
      {{mimetype, %{"schema" => schema}}, idx} ->
        {{idx, mimetype}, schema}
      _ -> nil
    end)
    |> Enum.filter(&(&1))
    |> Enum.into(%{})

    {String.to_integer(http_code), simplified_map}
  end

  #############################################################################
  ## trampolines work

  defp add_trampolines(parser, id, specmap) do
    parser
    |> add_single_success(specmap, id)
    |> add_all_responses(specmap, id)
  end

  @spec single_success?(simple_spec) :: boolean
  # returns true if a "simplflied response spec" has only one success condition.
  defp single_success?(specmap) do
    1 == specmap
    |> Enum.filter(fn {code, _} -> code < 300 end)
    |> Enum.count
  end

  defp type_block(typemap, id, code, fn_match) do
    cond do
      Enum.count(typemap) == 1 ->
        # the case when the typemap only contains one
        [{{idx, _}, _}] = Map.to_list(typemap)
        #set up the function call atoms
        id_fn = String.to_atom(id)
        trampoline_fn = [id, inspect(code), inspect(idx)]
        |> Enum.join("_")
        |> String.to_atom

        quote do
          def unquote(id_fn)(unquote(fn_match)) do
            unquote(trampoline_fn)(resp)
          end
        end

      true ->

        case_stmt = typemap
        |> Map.keys
        |> Enum.map(fn {idx, mimetype} ->
          trampoline_fn = [id, inspect(code), inspect(idx)]
          |> Enum.join("_")
          |> String.to_atom
          quote do
            {unquote(mimetype), value} -> unquote(trampoline_fn)(value)
          end
        end)
        |> AST.generate_piped_case

        quote do
          def root_response(unquote(fn_match)) do
            resp
            |> case do
              {:file, path} ->
                {MIME.from_path(path), File.read!(resp)}

              _ ->
                {"application/json", resp}
            end
            |> unquote(case_stmt)
          end
        end
    end
  end

  @spec single_success_block(simple_spec, String.t)::Macro.t
  defp single_success_block(specmap, id) do
    id_fn = String.to_atom(id)
    # retrieve the success item from the list.
    {code, _} = Enum.find(specmap, fn {code, _} -> code < 300 end)

    quote do
      def unquote(id_fn)({:ok, resp}) do
        unquote(id_fn)({:ok, unquote(code), resp})
      end
    end
  end

  @spec add_single_success(t, simple_spec, String.t)::t
  defp add_single_success(parser, specmap, id) do
    if single_success?(specmap) do
      trampoline = single_success_block(specmap, id)
      %__MODULE__{parser | trampolines: parser.trampolines ++ [trampoline]}
    else
      parser
    end
  end

  @spec add_all_responses(t, simple_spec, String.t)::t
  defp add_all_responses(parser, specmap, id) do
    trampolines = for {code, typemap} <- specmap do
      if code < 300 do
        type_block(typemap, id, code, quote do {:ok, unquote(code), resp} end)
      else
        type_block(typemap, id, code, quote do {:error, unquote(code), resp} end)
      end
    end
    %__MODULE__{parser | trampolines: parser.trampolines ++ trampolines}
  end

  defp add_final_trampoline(parser, id) do
    %__MODULE__{parser | trampolines: parser.trampolines ++ [ok_trampoline(id)]}
  end

  #############################################################################
  ## schemata work

  @spec add_schemata(t, String.t, simple_spec) :: t
  defp add_schemata(parser, id, spec) do
    schemata = Enum.map(spec, &schemata_for_code(&1, id))
    %__MODULE__{parser | schemata: parser.schemata ++ schemata}
  end

  @spec schemata_for_code({non_neg_integer, E.spec_map}, String.t) :: [Macro.t]
  defp schemata_for_code({http_code, cmap}, id) do
    new_id = Enum.join([id, http_code], "_")
    cmap
    |> Enum.map(&schema_for_type(&1, new_id))
    |> Enum.filter(&(&1))
    |> AST.splice_blocks
  end
  defp schemata_for_code(_, _), do: []

  @spec schema_for_type({{non_neg_integer, String.t}, Exonerate.json}, String.t)
    :: Macro.t
  defp schema_for_type({{idx, _}, schema}, id) do
    id_atom = [id, idx]
    |> Enum.join("_")
    |> String.to_atom

    spec_str = schema
    |> Jason.encode!(pretty: true)
    |> AST.ensigil

    {:defschema, [], [[{id_atom, spec_str}]]}
  end
  defp schema_for_type(_, _), do: nil

  alias Exaggerate.AST

  @spec finalize(t, String.t)::Macro.t | nil
  defp finalize(parser, id) do
    validation_block =
      AST.splice_blocks(parser.trampolines ++ parser.schemata)

    default_trampoline = ok_trampoline(id)

    quote do
      if Mix.env() in [:dev, :test] do
        unquote(validation_block)
      else
        unquote(default_trampoline)
      end
    end
  end

  defp ok_trampoline(id) do
    id_atom = String.to_atom(id)

    quote do
      def unquote(id_atom)(_) do
        :ok
      end
    end
  end

end
