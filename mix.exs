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
      escript: [main_module: Orian.CLI, name: "orian"],
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
      bench: ["orian.build", "orian.bench"],
      "orian.cli": ["orian.build", "escript.build"]
    ]
  end

  defp description do
    "s5cmd/Skyplane-class object transfer for Elixir: parallel cp/sync, BLAKE3, S3 and S5."
  end

  defp docs do
    [
      main: "Orian",
      extras: [
        "README.md",
        "LICENSE",
        "CHANGELOG.md",
        "HASH.md",
        "PERFORMANCE.md",
        "FUNDING.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "benchmark/RESULTS.md"
      ],
      source_ref: "v#{@version}"
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
        ~w(lib native/zig native/rust/src native/rust/Cargo.toml native/rust/Cargo.lock Makefile mix.exs README.md LICENSE CHANGELOG.md HASH.md PERFORMANCE.md FUNDING.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md benchmark/RESULTS.md .formatter.exs)
    ]
  end
end
