defmodule Exaggerate.Mixfile do
  use Mix.Project

  def project do
    Application.put_env(:exaggerate, :real_root, File.cwd!)
    [
      app: :exaggerate,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [ extra_applications: [:logger] ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:exonerate, git: "https://github.com/rstorlabs/exonerate.git", branch: "use_macros"},
      {:jason, "~> 1.1"},
      {:plug, "~> 1.7"},
    ]
  end
end
