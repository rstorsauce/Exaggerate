defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case
  import Exaggerate

  router "basic", """
  {
    "openapi": "3.0",
    "info": {
      "title": "api",
      "version": "0.1.0"
    },
    "consumes": [
      "application/json"
    ],
    "basePath": "/",
    "produces": [
      "application/json"
    ],
    "schemes": [
      "http"
    ],
    "paths": {
      "/": {
        "get": {
          "operationId": "root",
          "description": "gets root directory"
        }
      }
    }
  }
  """

  defmodule BasicWeb.Endpoint do
    def root(_conn) do
      {:ok, "received"}
    end
  end

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @port Enum.random(2000..3000)

  setup_all do
    children = [
      Cowboy.child_spec(scheme: :http,
                        plug: __MODULE__.BasicWeb.Router,
                        options: [port: @port])
    ]

    opts = [strategy: :one_for_one, name: FumApi.Supervisor]
    Supervisor.start_link(children, opts)
    :ok
  end

  describe "pinging the basic module" do
    test "can get a response from root" do
      resp = HTTPoison.get!("http://localhost:#{@port}/")
      assert resp.body == "received"
    end
  end

end
