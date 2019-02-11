defmodule ExaggerateTest.Validation.Schemata do
  defmacro in_path do
    """
    {
      "paths": {
        "/{id}": {
          "get": {
            "operationId": "by_id",
            "description": "gets by integer id",
            "parameters": [
              {"in": "path",
               "name": "id",
               "required": true,
               "schema": {"type": "integer", "minimum": 1}}
            ]
          }
        }
      }
    }
    """
  end
end

defmodule ExaggerateTest.Validation.IntegrationTest do

  use ExUnit.Case #, async: true
  import Exaggerate

  #alias and require our repository of Schemata
  alias ExaggerateTest.Validation.Schemata
  require Schemata

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @modules [:InPathWeb]
  @ports Enum.take_random(2000..15000, 50)
  @portmapper Enum.into(Enum.zip(@modules, @ports), %{})

  def child_def(module, port) do
    router = Module.concat([__MODULE__, module, :Router])
    Cowboy.child_spec(scheme: :http, plug: router, options: [port: port])
  end

  setup_all do
    children = for m <- @modules, do: child_def(m, @portmapper[m])
    opts = [strategy: :one_for_one, name: Cowboy.Supervisor2]
    Supervisor.start_link(children, opts)
    :ok
  end

  router "in_path", Schemata.in_path
  validator "in_path", Schemata.in_path

  defmodule InPathWeb.Endpoint do
    def by_id(_conn, value) when is_integer(value) do
      {:ok, "received #{value}"}
    end
  end

  describe "schema validation in-path for integers" do
    test "validator works as expected" do
      refute :ok == InPathWeb.Validator.by_id_parameters_0(0)
      assert :ok == InPathWeb.Validator.by_id_parameters_0(10)
    end

    test "positive control" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InPathWeb]}/20")
      assert resp.status_code == 200
      assert resp.body == "received 20"
    end

    test "bad number results in failure code" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InPathWeb]}/0")
      assert resp.status_code == 400
    end
  end


end
