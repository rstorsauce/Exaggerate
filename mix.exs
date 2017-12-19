defmodule Exaggerate.Mixfile do
  use Mix.Project

  def project do
    [
      app: :Exaggerate,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application, do: [applications: [:httpoison]]

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:httpoison, "~> 0.13"}
    ]
  end
end
