defmodule Validation.Helper do
  defmacro __using__(_args) do
    quote do
      import Validation.Helper
      require Poison
    end
  end

  defmacro passes(module, code) do
    quote do
      assert Module.concat(Exaggerate.Validation, unquote(module)).validate(unquote(code)) == :ok
    end
  end

  defmacro fails(module, code) do
    quote do
      {v1, v2, v3} = Module.concat(Exaggerate.Validation, unquote(module)).validate(unquote(code))
      assert v1 == :error
    end
  end
end

defmodule ExaggerateInfoUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @infobase """
  {
  "title": "Sample Pet Store App",
  "description": "This is a sample server for a pet store.",
  "termsOfService": "http://example.com/terms/",
  "contact": {
    "name": "API Support",
    "url": "http://www.example.com/support",
    "email": "support@example.com"
  },
  "license": {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  },
  "version": "1.0.1"
  }
  """ |> Poison.decode!

  test "sample info passes" do
    passes Info, @infobase
  end

  test "sample info without required data fails" do
    fails Info, @infobase |> Map.delete("title")
    fails Info, @infobase |> Map.delete("version")
  end

  test "sample info with optional data passes" do
    passes Info, @infobase |> Map.delete("description")
    passes Info, @infobase |> Map.delete("termsOfService")
    passes Info, @infobase |> Map.delete("contact")
    passes Info, @infobase |> Map.delete("license")
  end

  test "sample info with scrambled type fails" do
    fails Info, @infobase |> Map.put("title", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("version", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("description", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("termsOfService", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("contact", "this is not a contact object")
    fails Info, @infobase |> Map.put("license", %{"this is not" => "a license object"})
  end
end


defmodule ExaggerateContactUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @contactbase """
  {
    "name": "API Support",
    "url": "http://www.example.com/support",
    "email": "support@example.com"
  }
  """ |> Poison.decode!

  test "sample contact passes" do
    passes Contact, @contactbase
  end

  test "sample contact with optional data passes" do
    passes Contact, @contactbase |> Map.delete("name")
    passes Contact, @contactbase |> Map.delete("url")
    passes Contact, @contactbase |> Map.delete("email")
  end

  test "sample contact with scrambled type fails" do
    fails Contact, @contactbase |> Map.put("name", %{"this is not" => "a string"})
    fails Contact, @contactbase |> Map.put("url", "this is not an url")
    fails Contact, @contactbase |> Map.put("email", "this is not an email")
  end
end

defmodule ExaggerateLicenseUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @licensebase """
  {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  }
  """ |> Poison.decode!

  test "sample license passes" do
    passes License, @licensebase
  end

  test "sample license without required data fails" do
    fails License, @licensebase |> Map.delete("name")
  end

  test "sample license with optional data passes" do
    passes License, @licensebase |> Map.delete("url")
  end

  test "sample license with scrambled type fails" do
    fails License, @licensebase |> Map.put("name", %{"this is not" => "a string"})
    fails License, @licensebase |> Map.put("url", "this is not an url")
  end
end

defmodule ExaggerateServerUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @basicserverbase """
  {
    "url": "https://development.gigantic-server.com/v1",
    "description": "Development server"
  }
  """ |> Poison.decode!

  test "sample basic server passes" do
    passes Server, @basicserverbase
  end

  test "sample basic server without required data fails" do
    fails Server, @basicserverbase |> Map.delete("url")
  end

  test "sample basic server with optional data passes" do
    passes Server, @basicserverbase |> Map.delete("description")
  end

  test "sample basic server with scrambled type fails" do
    fails Server, @basicserverbase |> Map.put("url", "this is not an url")
    fails Server, @basicserverbase |> Map.put("description", %{"this is not" => "a string"})
  end

  @variableserverbase """
  {
    "url": "https://{username}.gigantic-server.com:{port}/{basePath}",
    "description": "The production API server",
    "variables": {
      "username": {
        "default": "demo",
        "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
      },
      "port": {
        "enum": [
          "8443",
          "443"
        ],
        "default": "8443"
      },
      "basePath": {
        "default": "v2"
      }
    }
  }
  """ |> Poison.decode!

  test "sample variable server passes" do
    passes Server, @variableserverbase
  end

  test "sample variable server with wonky variable fails" do
    fails Server, @variableserverbase |> Map.put("variables", %{"this is not" => "a server variable"})
  end
end


defmodule ExaggerateServerVariableUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @servervariablebase """
  {
    "default": "demo",
    "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
  }
  """ |> Poison.decode!

  test "sample servervariable passes" do
    passes ServerVariable, @servervariablebase
  end

  test "sample servervariable without required data fails" do
    fails ServerVariable, @servervariablebase |> Map.delete("default")
  end

  test "sample servervariable with optional data passes" do
    passes ServerVariable, @servervariablebase |> Map.delete("description")
  end

  test "sample servervariable with scrambled type fails" do
    fails ServerVariable, @servervariablebase |> Map.put("default", %{"this is not" => "a string"})
    fails ServerVariable, @servervariablebase |> Map.put("description", %{"this is not" => "a string"})
  end
end
