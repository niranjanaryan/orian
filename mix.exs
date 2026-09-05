defmodule Orian.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/niranjanaryan/orian"

  def project do
    [
      app: :orian,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      package: package(),
      description: description(),
      source_url: @source_url,
      homepage_url: "https://hex.pm/packages/orian",
      name: "Orian"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl, :public_key],
      mod: {Orian.Application, []}
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:rustler, "~> 0.38"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["orian.build", "test"],
      bench: ["orian.build", "orian.bench"]
    ]
  end

  defp description do
    "Fast content-addressed storage for Elixir: BLAKE3 + XXH3 (Zig/Rust NIFs), S3 and S5."
  end

  defp docs do
    [
      main: "Orian",
      extras: ["README.md", "LICENSE", "CHANGELOG.md", "HASH.md", "benchmark/RESULTS.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Niranjan Aryan"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Sponsor" => "https://github.com/sponsors/niranjanaryan",
        "Gale" => "https://github.com/niranjanaryan/gale",
        "Ingot" => "https://github.com/niranjanaryan/ingot",
        "Dusk" => "https://github.com/niranjanaryan/dusk"
      },
      files:
        ~w(lib native/zig native/rust/src native/rust/Cargo.toml Makefile mix.exs README.md LICENSE CHANGELOG.md HASH.md benchmark/RESULTS.md .formatter.exs)
    ]
  end
end
