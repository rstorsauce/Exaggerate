defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  defmodule MostBasic do
    import Exaggerate

    router """
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
            "description": "gets root directory",
            "responses": {}
          }
        }
      }
    }
    """
  end


end
