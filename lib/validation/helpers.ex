defmodule Exaggerate.Validation.Helpers do

  defmacro __using__(_opts) do
    quote do
      import Logger
      import Exaggerate.Validation.Helpers
    end
  end

  def validation_function_name(s) when is_atom(s), do: ("validate_" <> Atom.to_string(s)) |> String.to_atom

  def validation_call(obj) when is_atom(obj) do
    quote do
      unquote(validation_function_name(obj))(api_map)
    end
  end

  def required_call_generator(required_param) do
    validation_fn = validation_function_name(required_param)
    key_string = Atom.to_string(required_param)
    quote do
      def validate(api_map, [unquote(required_param) | tail], optional_list) do
        if Map.has_key?(api_map, unquote(key_string)) do
          Exaggerate.Validation.error_search([unquote(validation_fn)(api_map[unquote(key_string)]),
                                              validate(api_map, tail, optional_list)])
        else
          {:error, __MODULE__, "required key #{unquote(required_param)} is missing"}
        end
      end
    end
  end

  def optional_call_generator(optional_param) do
    validation_fn = validation_function_name(optional_param)
    key_string = Atom.to_string(optional_param)
    quote do
      def validate(api_map, [], [unquote(optional_param) | tail]) do
        if Map.has_key?(api_map, unquote(key_string)) do
          Exaggerate.Validation.error_search([unquote(validation_fn)(api_map[unquote(key_string)]),
                                              validate(api_map, [], tail)])
        else
          validate(api_map, [], tail)
        end
      end
    end
  end


  @doc """
    for a validation module, creates the validate function.  A validation module
    usually will implement this function, but for some corner cases, a special
    validate function may be hand-written.
  """
  defmacro validate_keys(required, optional) do
    required_validation_calls = Enum.map(required, &Exaggerate.Validation.Helpers.required_call_generator/1)
    optional_validation_calls = Enum.map(optional, &Exaggerate.Validation.Helpers.optional_call_generator/1)

    extra_results = quote do
      if Kernel.function_exported?(__MODULE__, :further_validation, 1) do
        Kernel.apply(__MODULE__, :further_validation, [api_map])
      else
        :ok
      end
    end

    quote do
      def validate(api_map), do: validate(api_map, unquote(required), unquote(optional))
      def validate(api_map,[],[]), do: unquote(extra_results)
      unquote(required_validation_calls)
      unquote(optional_validation_calls)
    end
  end

  defmacro string_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    param_str = Atom.to_string(parameter)
    quote do
      def unquote(vfunc)(str) when is_binary(str), do: :ok
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not a string, got #{inspect value}"}
    end
  end

  #TODO:  make this actually regexp over semantic versioning strings.
  defmacro version_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(ver) when is_binary(ver), do: :ok
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not a semantic version, got #{inspect value}"}
    end
  end

  defmacro object_parameter(parameter, modname \\ nil) do
    vfunc = validation_function_name(parameter)
    modname = modname || parameter |> Atom.to_string
                                   |> String.capitalize
                                   |> String.to_atom
    quote do
      def unquote(vfunc)(obj) when is_map(obj), do: Module.concat(Exaggerate.Validation, unquote(modname)).validate(obj)
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not an object, got #{inspect value}"}
    end
  end

  defmacro object_parameter(parameter, modname, alt_mod) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(obj) when is_map(obj) do
         primary_obj = Module.concat(Exaggerate.Validation, unquote(modname)).validate(obj)
         alt_obj =     Module.concat(Exaggerate.Validation, unquote(alt_mod)).validate(obj)

         Exaggerate.Validation.validation_or(primary_obj, alt_obj, {:error, __MODULE__, "parameter #{unquote(parameter)} does not conform to either option"})
      end
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not an object, got #{inspect value}"}
    end
  end

  defmacro boolean_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(value) when is_boolean(value), do: :ok
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not boolean, got #{inspect value}"}
    end
  end

  defmacro url_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(url) when is_binary(url) do
        case URI.parse(url) do
          %URI{scheme: nil} -> {:error, __MODULE__, "url \"#{url}\" does not contain a scheme"}
          %URI{host: nil} -> {:error, __MODULE__, "url \"#{url}\" does not contain a host"}
          _ -> :ok
        end
      end
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not a url, got #{inspect value}"}
    end
  end

  defmacro email_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(email) when is_binary(email) do
        if String.match?(email, ~r/\@/), do: :ok, else: {:error, __MODULE__, "#{unquote(parameter)} key's value is not an email, got #{inspect email}"}
      end
      def unquote(vfunc)(value), do: {:error, __MODULE__, "#{unquote(parameter)} key's value is not an email, got #{inspect value}"}
    end
  end

  defmacro sarray_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(arr) when is_list(arr) do
        valid = arr |> Enum.map(&Kernel.is_binary/1)
                    |> Enum.reduce(true, &Kernel.&&/2)
        if valid, do: :ok, else: {:error, __MODULE__, "parameter #{unquote(parameter)} contains non-string value"}
      end
    end
  end

  defmacro map_parameter(parameter, module) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(map) when is_map(map), do: :ok
    end
  end

  defmacro map_parameter(parameter, module, altmodule) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(map) when is_map(map), do: :ok
    end
  end

  defmacro array_parameter(parameter, module) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(arr) when is_list(arr), do: :ok
    end
  end

  defmacro array_parameter(parameter, module, altmodule) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(arr) when is_list(arr), do: :ok
    end
  end

  defmacro any_parameter(parameter) do
    vfunc = validation_function_name(parameter)
    quote do
      def unquote(vfunc)(_any), do: :ok
    end
  end

  defmacro pass_validate do
    quote do
      def validate(_) do
        Logger.warn("#{__MODULE__} is not currently validated")
        :ok
      end
    end
  end
end
