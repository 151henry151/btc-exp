defmodule BitcoinexExplorerWeb.ExplorerLiveTest do
  use BitcoinexExplorerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders explorer", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Bitcoinex Explorer"
    assert html =~ "Paste a Bitcoin address, BOLT11 Lightning invoice, or base64 PSBT"
    refute html =~ "phx-value-tab"
  end

  test "auto-detects Lightning invoice by ln prefix", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    inv =
      "lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp"

    html =
      view
      |> form("#decode-form", %{"input" => inv})
      |> render_change()

    assert html =~ "Lightning invoice (BOLT11)"
    assert html =~ "mainnet"
    assert html =~ "250000"
    assert html =~ "0.0025"
    refute html =~ "2.5e"
  end

  test "auto-detects PSBT by base64 magic", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    psbt =
      "cHNidP8BAHUCAAAAASaBcTce3/KF6Tet7qSze3gADAVmy7OtZGQXE8pCFxv2AAAAAAD+////AtPf9QUAAAAAGXapFNDFmQPFusKGh2DpD9UhpGZap2UgiKwA4fUFAAAAABepFDVF5uM7gyxHBQ8k0+65PJwDlIvHh7MuEwAAAQD9pQEBAAAAAAECiaPHHqtNIOA3G7ukzGmPopXJRjr6Ljl/hTPMti+VZ+UBAAAAFxYAFL4Y0VKpsBIDna89p95PUzSe7LmF/////4b4qkOnHf8USIk6UwpyN+9rRgi7st0tAXHmOuxqSJC0AQAAABcWABT+Pp7xp0XpdNkCxDVZQ6vLNL1TU/////8CAMLrCwAAAAAZdqkUhc/xCX/Z4Ai7NK9wnGIZeziXikiIrHL++E4sAAAAF6kUM5cluiHv1irHU6m80GfWx6ajnQWHAkcwRAIgJxK+IuAnDzlPVoMR3HyppolwuAJf3TskAinwf4pfOiQCIAGLONfc0xTnNMkna9b7QPZzMlvEuqFEyADS8vAtsnZcASED0uFWdJQbrUqZY3LLh+GFbTZSYG2YVi/jnF6efkE/IQUCSDBFAiEA0SuFLYXc2WHS9fSrZgZU327tzHlMDDPOXMMJ/7X85Y0CIGczio4OFyXBl/saiK9Z9R5E5CVbIBZ8hoQDHAXR8lkqASECI7cr7vCWXRC+B3jv7NYfysb3mk6haTkzgHNEZPhPKrMAAAAAAAAA"

    html =
      view
      |> form("#decode-form", %{"input" => psbt})
      |> render_change()

    assert html =~ "PSBT"
    assert html =~ "Inputs"
    assert html =~ "valid txid until finalized"
  end

  test "shows Bech32 checksum error for invalid bc1 address, not generic decode", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    bad = "bc1p5d7rjq7j6alvr7ghs086p45987z9sh9u6m6v0v607v607v607v6qsru639"

    html =
      view
      |> form("#decode-form", %{"input" => bad})
      |> render_change()

    assert html =~ "checksum verification failed"
    refute html =~ "Unable to decode address. Check the address and try again."
  end

  test "shows no error for empty input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#decode-form", %{"input" => ""})
      |> render_change()

    refute html =~ "Unable to decode"
  end

  test "shows friendly error for invalid invoice", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#decode-form", %{"input" => "lnbc1notvalid"})
      |> render_change()

    assert html =~ "Unable to decode invoice"
  end
end
