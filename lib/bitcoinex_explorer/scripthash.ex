defmodule BitcoinexExplorer.Scripthash do
  @moduledoc """
  Electrum / Fulcrum **scripthash**: `SHA256(scriptPubKey)` with **byte order reversed**
  before hex-encoding (little-endian wire order per Electrum protocol).

  Reversal matters: the hex string is **not** the same as the usual big-endian
  SHA256 display used elsewhere in Bitcoin tooling.
  """

  alias Bitcoinex.Script

  @doc """
  Returns lowercase hex scripthash for Electrum `blockchain.scripthash.*` calls.
  """
  @spec from_address(String.t()) :: {:ok, String.t()} | {:error, term()}
  def from_address(addr) when is_binary(addr) do
    case Script.from_address(addr) do
      {:ok, script, _network} ->
        spk = Script.serialize_script(script)
        <<h::binary-size(32)>> = :crypto.hash(:sha256, spk)
        rev = reverse_bytes(h)
        {:ok, Base.encode16(rev, case: :lower)}

      {:error, _} = err ->
        err
    end
  end

  defp reverse_bytes(<<>>), do: <<>>

  defp reverse_bytes(h) do
    :binary.list_to_bin(Enum.reverse(:binary.bin_to_list(h)))
  end
end
