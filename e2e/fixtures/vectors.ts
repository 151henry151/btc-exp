/**
 * Decodable fixtures aligned with RiverFinancial/bitcoinex tests (same strings must decode in-app).
 * https://github.com/RiverFinancial/bitcoinex
 */

/** Successful SegWit / legacy cases — substring assertions on the decoded summary UI */
export const ADDRESS_SUCCESS = [
  {
    name: "mainnet P2WPKH (bc1q)",
    input:
      "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
    expectText: ["mainnet", "p2wpkh", "0"],
  },
  {
    name: "mainnet P2WSH",
    input:
      "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3",
    expectText: ["mainnet", "p2wsh", "0"],
  },
  {
    name: "mainnet Taproot P2TR",
    input:
      "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0",
    expectText: ["mainnet", "p2tr", "1"],
  },
  {
    name: "testnet P2WSH (tb1q 32-byte witness)",
    input:
      "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
    expectText: ["testnet", "p2wsh"],
  },
  {
    name: "testnet Taproot",
    input:
      "tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c",
    expectText: ["testnet", "p2tr"],
  },
  {
    name: "mainnet legacy P2PKH (Base58)",
    input: "1AGNa15ZQXAZUgFiqJ2i7Z2DPU2J6hW62i",
    expectText: ["mainnet", "p2pkh", "legacy"],
  },
  {
    name: "mainnet legacy P2SH",
    input: "3CMNFxN1oHBc4R1EpboAL5yzHGgE611Xou",
    expectText: ["mainnet", "p2sh", "legacy"],
  },
  {
    name: "regtest P2WSH (bcrt1q 32-byte witness)",
    input:
      "bcrt1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qzf4jry",
    expectText: ["regtest", "p2wsh"],
  },
  {
    name: "BIP-350 long valid Taproot (bc1pw508… witness v1)",
    input:
      "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y",
    expectText: ["mainnet", "p2tr", "1"],
  },
] as const;

/** SegWit-looking strings that must surface SegWit-specific errors (not generic Base58 fallback) */
export const ADDRESS_SEGWIT_ERRORS = [
  {
    name: "bad checksum Taproot-shaped bc1p",
    input:
      "bc1p5d7rjq7j6alvr7ghs086p45987z9sh9u6m6v0v607v607v607v6qsru639",
    expectText: ["checksum verification failed"],
  },
  {
    name: "bad checksum (single-char typo in bc1q)",
    input:
      "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5",
    expectText: ["checksum verification failed"],
  },
  {
    name: "tc1 prefix falls through (not treated as bc1/tb1/bcrt1 Bech32 path)",
    input:
      "tc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq5zuyut",
    expectText: ["Unable to decode address"],
  },
  {
    name: "invalid program length (truncated bc1p)",
    input: "bc1pw5dgrnzv",
    expectText: ["Witness program length"],
  },
  {
    name: "invalid witness version (BC13…)",
    input: "BC13W508D6QEJXTDG4Y5R3ZARVARY0C5XW7KN40WF2",
    expectText: ["Invalid witness version"],
  },
] as const;

/** Garbage that is neither valid SegWit nor valid Base58 */
export const ADDRESS_TOTAL_FAILURE = [
  {
    name: "random ascii",
    input: "definitely-not-a-bitcoin-address-!!!",
    expectText: ["Unable to decode address"],
  },
] as const;

/** BOLT11 vectors from bitcoinex lightning invoice tests */
export const INVOICE_SUCCESS = [
  {
    name: "mainnet lnbc coffee",
    input:
      "lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp",
    expectText: ["mainnet", "250000", "0.0025", "cup coffee"],
  },
  {
    name: "testnet lntb",
    input:
      "lntb10n1pwt8uswpp5r7j8v60vnevkhxls93x2zp3xyu7z65a4368wh0en8fl70vpypa2sdpzfehjqstdda6kuapqwa5hg6pquju2me5ksucqzys5qzh8dzpqjz7k7pdlal68ew2vx0y9rwaqth758mu0yu0v367kuc8typ08g7tnhh3a7v53svay2efvn7fwah8pesjsgvwrdpjjj795gqp0g4utq",
    expectText: ["testnet"],
  },
] as const;

export const INVOICE_ERRORS = [
  {
    name: "truncated lnbc",
    input: "lnbc1notvalidtrunc",
    expectText: ["Unable to decode invoice"],
  },
] as const;

/** PSBT from bitcoinex PSBT tests (base64) — must parse and show input/output counts */
export const PSBT_VALID_MINIMAL = {
  name: "BIP174 fixture",
  input:
    "cHNidP8BAHUCAAAAASaBcTce3/KF6Tet7qSze3gADAVmy7OtZGQXE8pCFxv2AAAAAAD+////AtPf9QUAAAAAGXapFNDFmQPFusKGh2DpD9UhpGZap2UgiKwA4fUFAAAAABepFDVF5uM7gyxHBQ8k0+65PJwDlIvHh7MuEwAAAQD9pQEBAAAAAAECiaPHHqtNIOA3G7ukzGmPopXJRjr6Ljl/hTPMti+VZ+UBAAAAFxYAFL4Y0VKpsBIDna89p95PUzSe7LmF/////4b4qkOnHf8USIk6UwpyN+9rRgi7st0tAXHmOuxqSJC0AQAAABcWABT+Pp7xp0XpdNkCxDVZQ6vLNL1TU/////8CAMLrCwAAAAAZdqkUhc/xCX/Z4Ai7NK9wnGIZeziXikiIrHL++E4sAAAAF6kUM5cluiHv1irHU6m80GfWx6ajnQWHAkcwRAIgJxK+IuAnDzlPVoMR3HyppolwuAJf3TskAinwf4pfOiQCIAGLONfc0xTnNMkna9b7QPZzMlvEuqFEyADS8vAtsnZcASED0uFWdJQbrUqZY3LLh+GFbTZSYG2YVi/jnF6efkE/IQUCSDBFAiEA0SuFLYXc2WHS9fSrZgZU327tzHlMDDPOXMMJ/7X85Y0CIGczio4OFyXBl/saiK9Z9R5E5CVbIBZ8hoQDHAXR8lkqASECI7cr7vCWXRC+B3jv7NYfysb3mk6haTkzgHNEZPhPKrMAAAAAAAAA",
  /** Row labels plus visible input/output counts from the summary table */
  expectText: ["Inputs", "Outputs", "Input derivation paths", "Output amounts"],
} as const;

/** Malformed base64 / truncated PSBT */
export const PSBT_ERRORS = [
  {
    name: "not base64 (no PSBT magic — classified as address)",
    input: "@@@not-a-psbt@@@",
    expectText: ["Unable to decode address"],
  },
  {
    name: "truncated psbt magic",
    input: "cHNidP8BAA",
    expectText: ["Unable to decode PSBT"],
  },
] as const;
