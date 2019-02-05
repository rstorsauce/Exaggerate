defmodule M do
  defstruct v0: [], f1: [], f2: []

  @type t :: %__MODULE__{
    v0: [atom],
    f1: [N.custom],
    f2: [N.custom]
  }

  @spec push0(t, atom) :: t
  def push0(holder, value) do
    %__MODULE__{holder | v0: holder.v0 ++ [value]}
  end

  @spec push1(t, N.custom) :: t
  def push1(holder, value) do
    %__MODULE__{holder | f1: holder.f1 ++ [value]}
  end

  @spec push2(t, N.custom) :: t
  def push2(holder, value) do
    %__MODULE__{holder | f2: holder.f2 ++ [value]}
  end
end

defmodule N do
  @type custom :: {:<-, [any], [[any], ...]}
end
