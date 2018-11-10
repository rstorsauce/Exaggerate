defmodule Exaggerate.Codesynth do

  @project_root Path.relative_to_cwd("../../") |> Path.expand

  def swaggerfile_exists?(""), do: false
  def swaggerfile_exists?(filename), do: @project_root |> Path.join(filename) |> File.exists?
  def swaggerfile_isvalidate(filename) do
    swaggerfile_exists?(filename) && (@project_root |> Path.join(filename)
      |> File.read!
      |> Jason.decode!
      |> Exaggerate.Validation.OpenAPI.validate)
  end

  @doc """
    retrives function definitions from a code token array.

    iex> Exaggerate.Codesynth.get_defs(["def", "  ", "hi"]) #==>
    ["hi"]
  """
  def get_defs(arr) do
    # the list of tokens contains whitespace, so we should go ahead and filter
    # those out of before passing it to the get_defs/2 function, which contains
    # "smart state" denotating whether :def has been seen.
    arr |> Enum.map(&String.trim/1)
        |> Enum.filter(fn s -> s != "" end)
        |> get_defs(:no)
  end
  def get_defs([], :no), do: []
  def get_defs(["def" | tail], :no), do: get_defs(tail, :def)
  def get_defs([head | tail], :def), do: [head | get_defs(tail)]
  def get_defs([_head | tail], :no), do: get_defs(tail)

  def insert_code(new_functions, code_tokens) do
    new_code = Enum.slice(code_tokens, 0..-3) ++ ["\n" <> new_functions] ++ ["\n","end"] |> Enum.join
    new_code |> Code.format_string! |> Enum.join
  end

  def updateswaggerfile(swaggerfile), do: buildswaggerfile(swaggerfile, true)

  def buildswaggerfile(swaggerfile, update \\ false) do
    #first, find the .json extension
    modulename = (if String.match?(swaggerfile, ~r/.json$/), do: String.slice(swaggerfile, 0..-6), else: swaggerfile)
      |> String.capitalize

    moduledir = Path.join([@project_root, "lib", String.downcase(modulename)])

    swaggerfile_content = @project_root
      |> Path.join(swaggerfile)
      |> File.read!
      |> Jason.decode!

    route_content = swaggerfile_content
      |> Exaggerate.Codesynth.Routesynth.build_routemodule(swaggerfile, modulename)


    routerfile = Path.join(moduledir, "router.ex")

    #check to see if the module directory exists.
    endpoint_content = if update do
      if !File.exists?(moduledir), do: raise("directory #{moduledir} does not exist; cannot update swaggerfile")
      if !File.dir?(moduledir),    do: raise("directory #{moduledir} does not exist; cannot update swaggerfile")

      #remove the routerfile.
      if File.exists?(routerfile), do: File.rm!(routerfile)

      endpointfile = Path.join(moduledir, "endpoint.ex")

      if !File.exists?(endpointfile), do: raise("file #{endpointfile} does not exist; cannot update swaggerfile")

      endpointfile_tokens = Code.format_file!(endpointfile)
        |> fn [a | _b] -> a end.()  #format_file! returns a list of a list of tokens and a second value, throw away this second value.

      existing_defs = get_defs(endpointfile_tokens)

      #TODO:  consider refactoring build_routemodule to make this less opaque
      endpoint_content = swaggerfile_content["paths"]
        |> Exaggerate.Codesynth.Endpointsynth.build_endpoints(modulename, existing_defs)
        |> insert_code(endpointfile_tokens)

      endpoint_content
    else
      if File.exists?(moduledir), do: raise("directory #{moduledir} exists; cannot create swaggerfile")

      endpoint_content = swaggerfile_content
        |> Exaggerate.Codesynth.Endpointsynth.build_endpointmodule(swaggerfile, modulename)

      File.mkdir!(moduledir)

      endpoint_content
    end

    routerfile
      |> File.write!(route_content)
    Path.join(moduledir, "endpoint.ex")
      |> File.write!(endpoint_content)
  end
end
