defmodule ExaggerateTest.EndpointTest do
  use ExUnit.Case

  @moduletag :one

  alias Exaggerate.Endpoint
  alias Exaggerate.AST

  describe "testing endpoint generating defs" do
    test "endpoint block with no parameters works" do
      blockcode_res = """
      def testblock(conn) do
        # autogen function.
        # insert your code here, then delete
        # the next exception:
        raise "error: testblock not implemented"
      end
      """

      assert blockcode_res == :testblock
      |> Endpoint.block([])
      |> AST.to_string
    end

    test "endpoint block with one parameter works" do
      blockcode_res = """
      def testblock(conn, param1) do
        # autogen function.
        # insert your code here, then delete
        # the next exception:
        raise "error: testblock not implemented"
      end
      """

      assert blockcode_res == :testblock
      |> Endpoint.block([:param1])
      |> AST.to_string
    end

    test "endpoint block with two parameters works" do
      blockcode_res = """
      def testblock(conn, param1, param2) do
        # autogen function.
        # insert your code here, then delete
        # the next exception:
        raise "error: testblock not implemented"
      end
      """

      assert blockcode_res == :testblock
      |> Endpoint.block([:param1, :param2])
      |> AST.to_string
    end
  end

  describe "testing endpoint generating modules" do
    test "endpoint module works with one def in the module" do
      modcode_res = """
      defmodule ModuleTest.Web.Endpoint do
        def testblock1(conn) do
          # autogen function.
          # insert your code here, then delete
          # the next exception:
          raise "error: testblock1 not implemented"
        end
      end
      """

      assert modcode_res == "module_test"
      |> Endpoint.module(%{testblock1: []})
      |> AST.to_string
    end
  end

  test "endpoint module works with two defs in the module" do
    modcode_res = """
    defmodule ModuleTest.Web.Endpoint do
      def testblock1(conn) do
        # autogen function.
        # insert your code here, then delete
        # the next exception:
        raise "error: testblock1 not implemented"
      end

      def testblock2(conn, param) do
        # autogen function.
        # insert your code here, then delete
        # the next exception:
        raise "error: testblock2 not implemented"
      end
    end
    """

    assert modcode_res == "module_test"
    |> Endpoint.module(%{testblock1: [], testblock2: [:param]})
    |> AST.to_string
  end

end
