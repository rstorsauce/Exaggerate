defmodule Mix.Tasks.Exoneratebuildtests do
  use Mix.Task

  @rootdir  File.cwd!
  @testsdir  "test/JSONSchematests"
  @remoteroot "https://raw.githubusercontent.com/json-schema-org/JSON-Schema-Test-Suite/master/tests/draft4/"
  @tests ["additionalItems", "additionalProperties", #, "allOf", "anyOf"]
          "default",# "definitions"]#, #"dependencies", "enum",
          "items", "maxItems", "maxLength", "maxProperties", "maximum",
          "minItems", "minLength", "minProperties", "minimum",
          #"multipleOf", #"not", "oneOf"
          "pattern", "patternProperties", "properties",
          ##"ref", "refRemote",
          "required", "type", "uniqueItems"]

  def fetch_file(suite) do
    #generate the full uri from the suite name.
    file_uri = @remoteroot <> suite <> ".json"
    #fetch the uri and convert it from json to elixir
    HTTPoison.get!(file_uri).body
      |> Poison.decode!
  end

  def singletest(%{"description" => description, "data" => data, "valid" => valid}, function) do
    tester = if valid, do: "assert", else: "refute"
    """
      @tag :jsonschema
      test "#{description}" do
        data = #{inspect data}
        #{tester} #{function}(data) == :ok
      end
    """
  end

  def batchmodules({%{"description" => description,"schema" => schema, "tests" => tests}, idx}, modulename) do

    with :ok <- Exonerate.Validation.validate(schema) do
    else
       {:error, error} -> raise("error, #{inspect schema} appears to be invalid, throws #{error}")
    end

    schemacode = Exonerate.Codesynth.validator_string("test#{idx}", schema)

    testcode = tests |> Enum.map(&__MODULE__.singletest(&1, "validate_test#{idx}"))
                     |> Enum.join("\n")

    """
      defmodule #{modulename}#{idx} do

        @moduledoc \"""
          module for testing #{description}

          JSON Schema being tested:

          #{Poison.encode! schema}

        \"""

        use ExUnit.Case

        ##################################################
        #autogen code

        @doc "autogenerated schema code for #{description}"
        #{schemacode}

        ##################################################
        #test code

        #{testcode}
      end
    """
  end

  def buildtestmodules(testlist, module) do

    filename = Path.join([@rootdir, @testsdir, module <> "_test.exs"])
    modulename = String.capitalize(module)
    all_batches = testlist |> Enum.with_index
                           |> Enum.map(&__MODULE__.batchmodules(&1, modulename))
                           |> Enum.join("\n")

    """
    defmodule ExonerateTest.#{modulename} do
      #{all_batches}
    end
    """ |> Code.format_string! |> Enum.join |> fn txt -> File.write!(filename, txt) end.()
  end

  @shortdoc "generates mix tests from the JSONSchema test suite"
  def run(_) do
    #start the HTTPoison server
    HTTPoison.start
    #generate the library directory and refresh the directory.
    lib_dir = Path.join(@rootdir, @testsdir)
    if File.dir?(lib_dir), do: File.rm_rf!(lib_dir)
    File.mkdir_p!(lib_dir)

    for testsuite <- @tests do
      testsuite |> fetch_file
                |> buildtestmodules(testsuite)
    end

  end
end
