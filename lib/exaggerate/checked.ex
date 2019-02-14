defmodule Exaggerate.Checked do
  defmacro defchecked(call = {_, a, b}, expr) do

    call = quote do def(unquote(call),unquote(expr)) end

    if (Mix.env in [:dev, :test]) do
      quote do
        unquote(call)
      end
    else
      call
    end
  end
end
