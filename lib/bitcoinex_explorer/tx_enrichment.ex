defmodule BitcoinexExplorer.TxEnrichment do
  @moduledoc """
  Enrich Esplora vin/vout maps with Bitcoinex-derived fields for tables and tooling.
  """

  alias BitcoinexExplorer.Decode
  alias BitcoinexExplorer.OutputClassifier

  def enrich_vout(vout) when is_map(vout) do
    addr = Map.get(vout, "scriptpubkey_address") || ""
    value = Map.get(vout, "value")

    base = %{
      "value" => value,
      "scriptpubkey_type" => Map.get(vout, "scriptpubkey_type"),
      "scriptpubkey" => Map.get(vout, "scriptpubkey"),
      "scriptpubkey_asm" => Map.get(vout, "scriptpubkey_asm"),
      "scriptpubkey_address" => addr
    }

    ex =
      if addr != "" do
        case Decode.decode_address(addr) do
          {:ok, m} ->
            %{
              "bx_network" => m.network,
              "bx_address_type" => m.address_type,
              "bx_witness_version" => to_string(m.witness_version),
              "bx_witness_program_hex" => m.witness_program_hex,
              "bx_payload_hex" => Map.get(m, :payload_hex, ""),
              "bx_chart_type" => OutputClassifier.bucket_from_vout(vout) |> Atom.to_string()
            }

          {:error, _} ->
            %{
              "bx_network" => "",
              "bx_address_type" => Map.get(vout, "scriptpubkey_type") || "unknown",
              "bx_witness_version" => "",
              "bx_witness_program_hex" => "",
              "bx_payload_hex" => "",
              "bx_chart_type" => "unknown"
            }
        end
      else
        %{
          "bx_network" => "",
          "bx_address_type" => Map.get(vout, "scriptpubkey_type") || "unknown",
          "bx_witness_version" => "",
          "bx_witness_program_hex" => "",
          "bx_payload_hex" => "",
          "bx_chart_type" => Atom.to_string(OutputClassifier.bucket_from_vout(vout))
        }
      end

    Map.merge(base, ex)
  end

  def enrich_vin(vin) when is_map(vin) do
    coinbase? = Map.get(vin, "is_coinbase") == true
    prev = Map.get(vin, "prevout")

    cond do
      coinbase? ->
        %{
          "kind" => "coinbase",
          "coinbase_text" => coinbase_ascii(Map.get(vin, "scriptsig") || ""),
          "bx_prev_address" => "",
          "bx_prev_value_sats" => nil,
          "bx_network" => "",
          "bx_address_type" => "coinbase",
          "bx_witness_version" => "",
          "bx_witness_program_hex" => "",
          "bx_payload_hex" => ""
        }

      is_map(prev) ->
        addr = Map.get(prev, "scriptpubkey_address") || ""
        val = Map.get(prev, "value")

        ex =
          if addr != "" do
            case Decode.decode_address(addr) do
              {:ok, m} ->
                %{
                  "bx_network" => m.network,
                  "bx_address_type" => m.address_type,
                  "bx_witness_version" => to_string(m.witness_version),
                  "bx_witness_program_hex" => m.witness_program_hex,
                  "bx_payload_hex" => Map.get(m, :payload_hex, "")
                }

              {:error, _} ->
                %{
                  "bx_network" => "",
                  "bx_address_type" => Map.get(prev, "scriptpubkey_type") || "unknown",
                  "bx_witness_version" => "",
                  "bx_witness_program_hex" => "",
                  "bx_payload_hex" => ""
                }
            end
          else
            %{
              "bx_network" => "",
              "bx_address_type" => Map.get(prev, "scriptpubkey_type") || "unknown",
              "bx_witness_version" => "",
              "bx_witness_program_hex" => "",
              "bx_payload_hex" => ""
            }
          end

        Map.merge(
          %{
            "kind" => "spend",
            "prev_txid" => Map.get(vin, "txid"),
            "prev_vout" => Map.get(vin, "vout"),
            "bx_prev_address" => addr,
            "bx_prev_value_sats" => val
          },
          ex
        )

      true ->
        %{
          "kind" => "unknown",
          "bx_prev_address" => "",
          "bx_prev_value_sats" => nil,
          "bx_network" => "",
          "bx_address_type" => "unknown",
          "bx_witness_version" => "",
          "bx_witness_program_hex" => "",
          "bx_payload_hex" => ""
        }
    end
  end

  defp coinbase_ascii(hex) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} ->
        bin
        |> :binary.bin_to_list()
        |> Enum.filter(&(&1 >= 32 and &1 <= 126))
        |> List.to_string()
        |> String.slice(0, 120)

      _ ->
        ""
    end
  rescue
    _ -> ""
  end
end
