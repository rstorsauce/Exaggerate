defmodule Exaggerate.Tools do

  alias Plug.Conn

  @spec get_path(Plug.Conn.t, String.t, :string) :: {:ok, String.t}
  @spec get_path(Plug.Conn.t, String.t, :integer) :: {:ok, integer} | {:error, integer, String.t}
  def get_path(conn, index, format \\ :string)
  def get_path(conn, index, :string) do
    {:ok, conn.path_params[index]}
  end
  def get_path(conn, index, :integer) do
    val = conn.path_params[index]
    if val do
      val
      |> Integer.parse
      |> case do
        {v, ""} -> {:ok, v}
        _ -> {:error, 400, "malformed path component (#{index}): #{conn.path_params[index]}"}
      end
    else
      {:error, 400, "malformed query component: (#{index}) not provided"}
    end
  end

  @spec get_query(Plug.Conn.t, String.t, :string) :: {:ok, String.t}
  @spec get_query(Plug.Conn.t, String.t, :integer) :: {:ok, integer} | {:error, integer, String.t}
  def get_query(conn, index, format \\ :string) do
    conn
    |> Conn.fetch_query_params
    |> Map.get(:query_params)
    |> Map.get(index)
    |> check_format(format)
    |> handle_result(index)
  end

  @spec get_header(Plug.Conn.t, String.t, :string) :: {:ok, String.t} | {:error, integer, String.t}
  def get_header(conn, index, format \\ :string) do
    conn.req_headers
    |> find_header(index, format)
    |> check_format(format)
    |> handle_result(index)
  end

  defp find_header(headers, index, :string) do
    Enum.find_value(headers, fn
      {k, v} -> if k == String.downcase(index), do: v end)
  end

  @spec get_cookie(Plug.Conn.t, String.t, :string) :: {:ok, String.t} | {:error, integer, String.t}
  def get_cookie(conn, index, format \\ :string) do
    conn
    |> Conn.fetch_cookies
    |> Map.get(index)
    |> check_format(format)
    |> handle_result(index)
  end

  defp check_format(nil, _), do: nil
  defp check_format(v, :string), do: v
  defp check_format(v, :integer) do
    v
    |> Integer.parse
    |> case do
      {int_val, ""} -> int_val
      _ -> {:error, 400, "invalid integer: #{v}"}
    end
  end

  defp handle_result(nil, index), do: {:error, 400, "missing value: #{index}"}
  defp handle_result(e = {:error, _, _}, _), do: e
  defp handle_result(v, _), do: {:ok, v}
end
