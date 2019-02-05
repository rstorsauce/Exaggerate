defmodule Exaggerate do
  @moduledoc """
  Swagger -> Plug DSL.

  this module also provides some macros which you can use
  in the case that you want to do something cute.
  """

  defmacro router(swaggertext) do
    # takes some swagger text and expands it so that the current
    # module is a desired router.
  end
end
