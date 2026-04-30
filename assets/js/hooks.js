import * as d3 from "d3"
import QRCode from "qrcode"

const COLORS = {
  p2pkh: "#fbbf24",
  p2sh: "#fb923c",
  p2wpkh: "#3b82f6",
  p2wsh: "#6366f1",
  p2tr: "#a855f7",
  coinbase: "#71717a",
  op_return: "#9f1239",
  unknown: "#71717a",
}

function parseChartData(el) {
  try {
    return JSON.parse(el.dataset.chartdata || "[]")
  } catch (_) {
    return []
  }
}

export const ScriptTypeChart = {
  mounted() {
    this.renderChart(true)
  },
  updated() {
    this.renderChart(false)
  },
  renderChart(initial) {
    const data = parseChartData(this.el)
    const width = Math.max(this.el.clientWidth || 600, 280)
    const barHeight = 28
    const margin = { top: 8, right: 16, bottom: 8, left: 8 }

    d3.select(this.el).selectAll("svg").remove()

    const total = d3.sum(data, (d) => d.count) || 1
    const svg = d3
      .select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", barHeight + margin.top + margin.bottom + 40)

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    let x = 0
    const innerW = width - margin.left - margin.right

    data.forEach((d, i) => {
      const w = innerW * (d.count / total)
      const color = COLORS[d.key] || COLORS.unknown
      const rect = g
        .append("rect")
        .attr("x", x)
        .attr("y", 0)
        .attr("width", Math.max(w, 2))
        .attr("height", barHeight)
        .attr("fill", color)
        .attr("rx", 4)

      if (!initial) {
        rect.transition().duration(400).attr("width", Math.max(w, 2))
      }

      if (w > 48) {
        g.append("text")
          .attr("x", x + w / 2)
          .attr("y", barHeight / 2 + 4)
          .attr("text-anchor", "middle")
          .attr("fill", "#0f0f0f")
          .attr("font-size", "11px")
          .text(`${d.type}: ${d.count}`)
      }

      x += w
    })

    const legend = svg.append("g").attr("transform", `translate(${margin.left},${barHeight + margin.top + 16})`)

    data.forEach((d, i) => {
      const lx = (i % 4) * (innerW / 4)
      const ly = Math.floor(i / 4) * 18
      legend
        .append("rect")
        .attr("x", lx)
        .attr("y", ly)
        .attr("width", 12)
        .attr("height", 12)
        .attr("fill", COLORS[d.key] || COLORS.unknown)
      legend
        .append("text")
        .attr("x", lx + 16)
        .attr("y", ly + 10)
        .attr("fill", "#a1a1aa")
        .attr("font-size", "11px")
        .text(`${d.type}`)
    })
  },
}

function parseTxData(el) {
  try {
    return JSON.parse(el.dataset.txdata || "{}")
  } catch (_) {
    return {}
  }
}

export const TxFlowGraph = {
  mounted() {
    this.redraw()
  },
  updated() {
    this.redraw()
  },
  redraw() {
    const { inputs = [], outputs = [] } = parseTxData(this.el)
    d3.select(this.el).selectAll("svg").remove()

    const maxVal =
      Math.max(
        1,
        ...inputs.map((i) => i.value_sats || 0),
        ...outputs.map((o) => o.value_sats || 0)
      ) || 1

    const pad = 16
    const colW = 140
    const midW = 72
    const rowH = outputs.length >= 4 ? 46 : 36
    const hIn = Math.max(inputs.length * rowH + pad * 2, 120)
    const hOut = Math.max(outputs.length * rowH + pad * 2, 120)
    const height = Math.max(hIn, hOut, 160)
    const width = colW + midW + colW + pad * 4

    const svg = d3
      .select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", `0 0 ${width} ${height}`)

    const g = svg.append("g")

    const cx = pad + colW + midW / 2
    const cy = height / 2

    g.append("rect")
      .attr("x", cx - 28)
      .attr("y", cy - 18)
      .attr("width", 56)
      .attr("height", 36)
      .attr("rx", 6)
      .attr("fill", "#27272a")
      .attr("stroke", "#f7931a")

    g.append("text")
      .attr("x", cx)
      .attr("y", cy + 5)
      .attr("text-anchor", "middle")
      .attr("fill", "#fafafa")
      .attr("font-size", "13px")
      .attr("font-weight", "600")
      .text("TX")

    const hook = this

    function strokeFor(val) {
      const r = val / maxVal
      return 1 + r * 7
    }

    inputs.forEach((inp, i) => {
      const y = pad + i * rowH + rowH / 2
      const x1 = pad + colW
      const label = truncateAddr(inp.address)
      const color = COLORS[inp.type] || COLORS.unknown

      const inStroke =
        inp.type === "coinbase"
          ? Math.max(2, strokeFor(inp.value_sats || 0))
          : strokeFor(inp.value_sats || 0)

      g.append("line")
        .attr("x1", pad)
        .attr("y1", y)
        .attr("x2", cx - 28)
        .attr("y2", cy)
        .attr("stroke", "#52525b")
        .attr("stroke-width", inStroke)

      const ng = g.append("g").style("cursor", inp.address && inp.address !== "Coinbase" ? "pointer" : "default")

      ng.append("circle").attr("cx", pad + 8).attr("cy", y).attr("r", 8).attr("fill", color)

      ng.append("text")
        .attr("x", pad + 22)
        .attr("y", y + 4)
        .attr("fill", "#e4e4e7")
        .attr("font-size", "11px")
        .on("click", () => {
          if (inp.address && inp.address !== "Coinbase" && inp.address !== "non-standard") {
            hook.pushEvent("goto_address", { address: inp.address })
          }
        })
        .text(`${label} · ${inp.value_sats ?? 0} sat`)
    })

    outputs.forEach((out, i) => {
      const y = pad + i * rowH + rowH / 2
      const label = truncateAddr(out.address)
      const color = COLORS[out.type] || COLORS.unknown
      const outNavigable =
        out.address && out.address !== "non-standard" && out.address !== "OP_RETURN"

      g.append("line")
        .attr("x1", cx + 28)
        .attr("y1", cy)
        .attr("x2", width - pad)
        .attr("y2", y)
        .attr("stroke", "#52525b")
        .attr("stroke-width", strokeFor(out.value_sats || 0))

      const ng = g.append("g").style("cursor", outNavigable ? "pointer" : "default")

      ng.append("circle").attr("cx", width - pad - 8).attr("cy", y).attr("r", 8).attr("fill", color)

      ng.append("text")
        .attr("x", width - pad - 22)
        .attr("y", y + 4)
        .attr("fill", "#e4e4e7")
        .attr("font-size", "11px")
        .attr("text-anchor", "end")
        .on("click", () => {
          if (outNavigable) {
            hook.pushEvent("goto_address", { address: out.address })
          }
        })
        .text(`${label} · ${out.value_sats ?? 0} sat`)
    })
  },
}

function truncateAddr(addr) {
  if (!addr || addr.length < 18) return addr || ""
  return `${addr.slice(0, 8)}…${addr.slice(-6)}`
}

export const RelativeTime = {
  mounted() {
    this.tick = () => {
      const unix = parseInt(this.el.dataset.unix || "0", 10)
      if (!unix) return
      const diff = Math.floor(Date.now() / 1000) - unix
      this.el.textContent = humanizeDiff(diff)
    }
    this.tick()
    this.timer = setInterval(this.tick, 30_000)
  },
  destroyed() {
    if (this.timer) clearInterval(this.timer)
  },
}

function humanizeDiff(sec) {
  if (sec < 60) return `${sec}s ago`
  if (sec < 3600) return `${Math.floor(sec / 60)}m ago`
  if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`
  return `${Math.floor(sec / 86400)}d ago`
}

export const AddressQr = {
  mounted() {
    this.render()
  },
  updated() {
    this.render()
  },
  render() {
    const addr = this.el.dataset.address || ""
    this.el.innerHTML = ""
    if (!addr) return
    const canvas = document.createElement("canvas")
    QRCode.toCanvas(canvas, addr, { width: 128, margin: 1, color: { dark: "#fafafa", light: "#18181b00" } }).catch(
      () => {}
    )
    this.el.appendChild(canvas)
  },
}

export default {
  ScriptTypeChart,
  TxFlowGraph,
  RelativeTime,
  AddressQr,
}
