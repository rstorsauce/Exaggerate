defmodule Exaggerate.Endpoint do

  @type defmod_ast  :: {:defmodule, any, any}
  @type def_ast     :: {:def, any, any}
  @type endpointmap :: %{required(atom) => list(atom)}

  @doc """
  generates a skeleton endpoint module from an module name (string) and an
  endpoint map, which is a map structure representing atoms matched with a
  list of parameters to be passed into the map.

  Typically, the module name will derive from the basename of the json file
  from which the swagger template comes.  In general, this function will be
  called by `mix swagger` but not `mix swagger update`, which will parse out
  the existing functions first.
  """

  @spec module(String.t, endpointmap) :: defmod_ast
  def module(module_name, endpoints) do
    code = Enum.map(endpoints, &block/1)

    module = module_name
    |> Macro.camelize
    |> Module.concat(Web.Endpoint)

    quote do
      defmodule unquote(module) do
        unquote_splicing(code)
      end
    end
  end

  @doc """
  generates a skeleton endpoint block from an endpoint name (atom) and a
  list of matched variables.

  This block is intended to be filled out by the user.  @comment values
  are going to be swapped out, later in AST processing, for # comments.
  """
  @spec block({atom, [atom]}) :: def_ast
  def block({ep, v}), do: block(ep, v)
  @spec block(atom, [atom]) :: def_ast
  def block(endpoint, vars) do
    raise_str = "error: #{endpoint} not implemented"
    mvars = Enum.map(vars, fn var -> {var, [], Elixir} end)
    quote do
      def unquote(endpoint)(conn, unquote_splicing(mvars)) do
        @comment "autogen function."
        @comment "insert your code here, then delete"
        @comment "the next exception:"

        raise unquote(raise_str)
      end
    end
  end

end
