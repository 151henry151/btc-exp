defmodule BitcoinexExplorerTest.Fixtures do
  @moduledoc false

  def path(rel) when is_binary(rel) do
    Path.join([__DIR__, "..", "fixtures", rel])
  end

  def read_json!(rel) do
    rel |> path() |> File.read!() |> Jason.decode!()
  end
end
