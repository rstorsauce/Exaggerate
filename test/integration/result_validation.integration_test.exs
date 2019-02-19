defmodule ExaggerateTest.ResultValidation.Schemata do
  defmacro basic_validated do
    """
    {
      "paths": {
        "/": {
          "get": {
            "operationId": "root",
            "description": "gets by integer id",
            "responses": {
              "200": {
                "description": "pet response",
                "content": {
                  "application/json": {
                    "schema": {
                      "type":"object",
                      "properties":{
                        "foo":{"type": "string"}
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """
  end
end

defmodule ExaggerateTest.ResultValidation.IntegrationTest do

  use ExUnit.Case
  import Exaggerate
  import Exaggerate.Validator
  import Exaggerate.Router

  #alias and require our repository of Schemata
  alias ExaggerateTest.ResultValidation.Schemata
  require Schemata

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @modules [:BasicValidatedWeb]
  @ports Enum.take_random(2000..15000, 50)
  @portmapper Enum.into(Enum.zip(@modules, @ports), %{})

  def child_def(module, port) do
    router = Module.concat([__MODULE__, module, :Router])
    Cowboy.child_spec(scheme: :http, plug: router, options: [port: port])
  end

  setup_all do
    children = for m <- @modules, do: child_def(m, @portmapper[m])
    opts = [strategy: :one_for_one, name: Cowboy.Supervisor3]
    Supervisor.start_link(children, opts)

    #also create an agent which is going to store some state we'll preload.
    Agent.start(fn -> nil end, name: ResultValidator)

    :ok
  end

  router "basic_validated", Schemata.basic_validated
  validator "basic_validated", Schemata.basic_validated

  defmodule BasicValidatedWeb.Endpoint do
    def root(_conn) do
      {:ok, Agent.get(ResultValidator, &(&1))}
    end
  end

  describe "response validation" do
    test "a validation that matches passes" do
      Agent.update(ResultValidator, fn _ -> %{"foo" => "bar"} end)
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:BasicValidatedWeb]}/")
      assert resp.status_code == 200
      assert resp.body == ~s({"foo":"bar"})
    end
    test "a validation that doesn't match 500s" do
      Agent.update(ResultValidator, fn _ -> "this is intended to error" end)

      {:ok, resp} = BasicValidatedWeb.Endpoint.root(:conn)
      BasicValidatedWeb.Validator.root_response(resp)
      BasicValidatedWeb.Validator.root_response_200_0(resp)

      resp = HTTPoison.get!("http://localhost:#{@portmapper[:BasicValidatedWeb]}/")
      assert resp.status_code == 500
    end
  end

end

