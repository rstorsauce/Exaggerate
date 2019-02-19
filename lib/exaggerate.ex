defmodule Exaggerate do

  @moduledoc """
  Swagger -> Plug DSL.

  this module also provides some macros which you can use
  in the case that you want to do something cute.
  """

  @type spec_data :: float | integer | String.t
  | [spec_data] | %{optional(String.t) => spec_data}

  @typedoc """
  maps containing swagger spec information.
  """
  @type spec_map :: %{optional(String.t) => spec_data}

  @type http_verb :: :get | :post | :put | :patch |
                     :delete | :head | :options | :trace
  @type route :: {String.t, http_verb}

  @type error :: {:error, integer, String.t}

end
