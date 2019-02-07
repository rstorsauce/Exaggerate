defmodule ExaggerateTest.Router.ComponentTest do

  use ExUnit.Case

  alias Exaggerate.Router

  describe "success_code" do
    test "maps without responses default to 200" do
      assert 200 = Router.success_code(%{})
    end

    test "maps with a single success response override 200" do
      assert 201 = Router.success_code(%{
        "responses" => %{"201" => "success"}
      })

      assert 201 = Router.success_code(%{
        "responses" => %{"201" => %{"description" => "success"},
                         "400" => %{"description" => "fail"}}
      })

      assert 100 = Router.success_code(%{
        "responses" => %{"100" => %{"description" => "continue"},
                         "400" => %{"description" => "fail"},
                         "404" => %{"description" => "not there"}}
      })
    end

    test "maps with multiple success responses output multi" do
      assert :multi = Router.success_code(%{
        "responses" => %{"100" => %{"description" => "continue"},
                         "200" => %{"description" => "success"},
                         "404" => %{"description" => "not there"}}
      })

      assert :multi = Router.success_code(%{
        "responses" => %{"100" => %{"description" => "continue"},
                         "200" => %{"description" => "success"},
                         "404" => %{"description" => "not there"},
                         "500" => %{"description" => "oopsie"}}
      })
    end

    test "maps with a variable outputs automatically multi" do
      assert :multi = Router.success_code(%{
        "responses" => %{"2XX" => "success"}
      })

      assert :multi = Router.success_code(%{
        "responses" => %{"2XX" => %{"description" => "success"},
                         "400" => %{"description" => "fail"}}
      })

      assert :multi = Router.success_code(%{
        "responses" => %{"1XX" => %{"description" => "continue"},
                         "400" => %{"description" => "fail"},
                         "404" => %{"description" => "not there"}}
      })
    end
  end

end
