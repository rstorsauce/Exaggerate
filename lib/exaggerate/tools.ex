defmodule Exaggerate.Tools do

  alias Plug.Conn
  @type error :: {:error, integer, String.t}

  @spec get_path(Plug.Conn.t, String.t, :string) :: {:ok, String.t}
  @spec get_path(Plug.Conn.t, String.t, :integer) :: {:ok, integer} | error
  def get_path(conn, index, format \\ :string) do
    conn
    |> Map.get(:path_params)
    |> Map.get(index)
    |> check_format(format)
    |> validate_content(index)
  end

  @spec get_query(Plug.Conn.t, String.t, :string) :: {:ok, String.t}
  @spec get_query(Plug.Conn.t, String.t, :integer) :: {:ok, integer} | error
  def get_query(conn, index, format \\ :string) do
    conn
    |> Conn.fetch_query_params
    |> Map.get(:query_params)
    |> Map.get(index)
    |> check_format(format)
    |> validate_content(index)
  end

  @spec get_header(Plug.Conn.t, String.t, :string) :: {:ok, String.t} | error
  def get_header(conn, index, format \\ :string) do
    conn.req_headers
    |> find_header(index)
    |> check_format(format)
    |> validate_content(index)
  end

  @spec find_header([{String.t, String.t}], String.t) :: String.t
  defp find_header(headers, index) do
    Enum.find_value(headers, fn
      {k, v} -> if k == String.downcase(index), do: v end)
  end

  @spec get_cookie(Plug.Conn.t, String.t, :string) :: {:ok, String.t} | error
  def get_cookie(conn, index, format \\ :string) do
    conn
    |> Conn.fetch_cookies
    |> Map.get(:cookies)
    |> Map.get(index)
    |> check_format(format)
    |> validate_content(index)
  end

  @spec match_mimetype(Plug.Conn.t, [String.t])::{:ok, String.t} | error
  def match_mimetype(conn, mimetypes) when is_list(mimetypes) do
    conn.req_headers
    |> find_mimetype
    |> Plug.Conn.Utils.media_type
    |> case do
      {:ok, conn_type, conn_subtype, _} ->
        match_mimetype({conn_type, conn_subtype}, mimetypes, nil)
      :error -> {:error, :mimetype}
    end
  end

  @spec match_mimetype({String.t, String.t}, [String.t], String.t | nil) :: String.t
  def match_mimetype(_, [], nil), do: {:error, :mimetype}
  def match_mimetype(_, [], maybe_type), do: {:ok, maybe_type}
  def match_mimetype(c = {conn_type, conn_subtype}, [head | tail], maybe_type) do
    {:ok, tgt_type, tgt_subtype, _} = Plug.Conn.Utils.media_type(head)
    cond do
      # if both match, cut out and return "head"
      {conn_type, conn_subtype} == {tgt_type, tgt_subtype} ->
        {:ok, head}

      # if only the major type matches, stuff it into the "maybe slot"
      {conn_type, "*"} == {tgt_type, tgt_subtype} ->
        match_mimetype(c, tail, head)

      # if we have a total wildcard (note: only gets shoved in the "maybe slot"
      # if there wasn't anything there before)
      {"*", "*", nil} == {tgt_type, tgt_subtype, maybe_type} ->
        match_mimetype(c, tail, head)

      # keep looking.
      true ->
        match_mimetype(c, tail, maybe_type)
    end
  end

  @spec find_mimetype([{String.t, String.t}])::String.t
  defp find_mimetype([]), do: {:error, :mimetype}
  defp find_mimetype([{"content-type", c} | _]), do: c
  defp find_mimetype([_ | tail]), do: find_mimetype(tail)

  @spec get_body(Plug.Conn.t) :: {:ok, any}
  def get_body(conn) do
    validate_content(conn.body_params, "content")
  end

  ###############################################################
  ## general helper utility functions

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

  defp validate_content(nil, index), do: {:error, 400, "missing value: #{index}"}
  defp validate_content(e = {:error, _, _}, _), do: e
  defp validate_content(%{"_json" => v}, _), do: {:ok, v}
  defp validate_content(v, _), do: {:ok, v}
end
