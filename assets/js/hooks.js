import * as d3 from "d3"
import jsQR from "jsqr"
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
    this._resizeQueued = false
    this._onResize = () => {
      if (this._resizeQueued) return
      this._resizeQueued = true
      requestAnimationFrame(() => {
        this._resizeQueued = false
        this.redraw()
      })
    }
    this.redraw()
    this._ro = new ResizeObserver(this._onResize)
    this._ro.observe(this.el)
  },
  updated() {
    this.redraw()
  },
  destroyed() {
    if (this._ro) {
      this._ro.disconnect()
      this._ro = null
    }
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

    const pad = 20
    const minW = 400
    const measured = Math.floor(this.el.getBoundingClientRect().width)
    const width = measured > 48 ? measured : minW

    const rowH = outputs.length >= 4 ? 46 : 36
    const hIn = Math.max(inputs.length * rowH + pad * 2, 120)
    const hOut = Math.max(outputs.length * rowH + pad * 2, 120)
    const height = Math.max(hIn, hOut, 160)

    const svg = d3
      .select(this.el)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", `0 0 ${width} ${height}`)
      .style("display", "block")

    const g = svg.append("g")

    const cx = width / 2
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
      return 0.9 + r * 2.2
    }

    inputs.forEach((inp, i) => {
      const y = pad + i * rowH + rowH / 2
      const label = truncateAddr(inp.address)
      const color = COLORS[inp.type] || COLORS.unknown

      const inStroke =
        inp.type === "coinbase"
          ? Math.max(1.1, strokeFor(inp.value_sats || 0))
          : strokeFor(inp.value_sats || 0)

      g.append("line")
        .attr("x1", pad)
        .attr("y1", y)
        .attr("x2", cx - 28)
        .attr("y2", cy)
        .attr("stroke", "#52525b")
        .attr("stroke-width", inStroke)
        .attr("stroke-linecap", "round")

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
        .attr("stroke-linecap", "round")

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

/** Strip bitcoin:/lightning: wrappers common in wallet QR codes. */
function normalizeQrPayload(text) {
  const t = String(text || "").trim()
  if (!t) return t
  const lower = t.toLowerCase()
  if (lower.startsWith("bitcoin:")) {
    return t.slice("bitcoin:".length).split(/[?#]/)[0].trim()
  }
  if (lower.startsWith("lightning:")) {
    return t.slice("lightning:".length).split(/[?#]/)[0].trim()
  }
  return t
}

function applyDecodedValue(input, rawText) {
  const normalized = normalizeQrPayload(rawText)
  input.focus()
  input.value = normalized
  input.dispatchEvent(new Event("input", { bubbles: true }))
}

export const QrScan = {
  mounted() {
    this.targetSelector = this.el.dataset.targetSelector || ""
    this.afterScan = this.el.dataset.afterScan || "decode-change"
    this.btn = this.el.querySelector("[data-qr-trigger]")
    this._onTrigger = (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.openScanner()
    }
    this.btn?.addEventListener("click", this._onTrigger)
    this.stream = null
    this.rafId = null
    this.overlay = null
    this.video = null
    this.canvas = null
    this.active = false
  },
  destroyed() {
    this.btn?.removeEventListener("click", this._onTrigger)
    this.closeScanner()
  },
  updated() {},
  closeScanner() {
    this.active = false
    if (this.rafId != null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop())
      this.stream = null
    }
    if (this.overlay?.parentNode) {
      this.overlay.parentNode.removeChild(this.overlay)
    }
    this.overlay = null
    this.video = null
    this.canvas = null
  },
  openScanner() {
    if (!this.targetSelector || !navigator.mediaDevices?.getUserMedia) {
      window.alert("Camera scanning is not supported in this browser.")
      return
    }

    const input = document.querySelector(this.targetSelector)
    if (!input) return

    this.closeScanner()
    this.active = true

    const overlay = document.createElement("div")
    overlay.setAttribute("role", "dialog")
    overlay.setAttribute("aria-modal", "true")
    overlay.setAttribute("aria-label", "Scan QR code")
    Object.assign(overlay.style, {
      position: "fixed",
      inset: "0",
      zIndex: "100",
      background: "rgba(0,0,0,0.92)",
      display: "flex",
      flexDirection: "column",
      padding: "12px",
      boxSizing: "border-box",
    })

    const bar = document.createElement("div")
    Object.assign(bar.style, {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      marginBottom: "10px",
      gap: "8px",
    })

    const title = document.createElement("div")
    title.textContent = "Scan QR code"
    Object.assign(title.style, { color: "#fafafa", fontSize: "16px", fontWeight: "600" })

    const cancelBtn = document.createElement("button")
    cancelBtn.type = "button"
    cancelBtn.textContent = "Cancel"
    Object.assign(cancelBtn.style, {
      padding: "8px 14px",
      borderRadius: "8px",
      border: "1px solid #52525b",
      background: "#27272a",
      color: "#fafafa",
      fontSize: "14px",
      cursor: "pointer",
    })
    cancelBtn.addEventListener("click", () => this.closeScanner())

    bar.appendChild(title)
    bar.appendChild(cancelBtn)

    const errEl = document.createElement("p")
    Object.assign(errEl.style, {
      color: "#fdba74",
      fontSize: "13px",
      margin: "0 0 8px 0",
      minHeight: "1.2em",
    })

    const video = document.createElement("video")
    video.setAttribute("playsinline", "")
    video.playsInline = true
    video.muted = true
    Object.assign(video.style, {
      flex: "1",
      width: "100%",
      minHeight: "0",
      borderRadius: "12px",
      border: "1px solid #3f3f46",
      objectFit: "cover",
      background: "#000",
    })

    const canvas = document.createElement("canvas")

    overlay.appendChild(bar)
    overlay.appendChild(errEl)
    overlay.appendChild(video)
    document.body.appendChild(overlay)

    this.overlay = overlay
    this.video = video
    this.canvas = canvas

    navigator.mediaDevices
      .getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false,
      })
      .then((stream) => {
        if (!this.active) {
          stream.getTracks().forEach((t) => t.stop())
          return
        }
        this.stream = stream
        video.srcObject = stream
        video.play().catch(() => {})

        const ctx = canvas.getContext("2d", { willReadFrequently: true })
        const tick = () => {
          if (!this.active || !this.video || !ctx) return

          if (video.readyState >= video.HAVE_CURRENT_DATA) {
            canvas.width = video.videoWidth
            canvas.height = video.videoHeight
            ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
            const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
            const code = jsQR(imageData.data, imageData.width, imageData.height, {
              inversionAttempts: "attemptBoth",
            })
            if (code?.data) {
              const text = String(code.data).trim()
              if (text) {
                applyDecodedValue(input, text)
                this.closeScanner()
                if (this.afterScan === "submit-search") {
                  const form = input.form
                  if (form) form.requestSubmit()
                }
                return
              }
            }
          }
          this.rafId = requestAnimationFrame(tick)
        }
        this.rafId = requestAnimationFrame(tick)
      })
      .catch(() => {
        errEl.textContent = "Could not access the camera. Check permissions and try again."
      })
  },
}

function escapeHtmlLightning(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

function lightningBfsLayers(startId, plainLinks) {
  const adj = new Map()
  for (const e of plainLinks) {
    if (!adj.has(e.source)) adj.set(e.source, [])
    if (!adj.has(e.target)) adj.set(e.target, [])
    adj.get(e.source).push(e.target)
    adj.get(e.target).push(e.source)
  }
  const dist = new Map()
  const q = [startId]
  dist.set(startId, 0)
  let qi = 0
  while (qi < q.length) {
    const u = q[qi++]
    const du = dist.get(u)
    for (const v of adj.get(u) || []) {
      if (!dist.has(v)) {
        dist.set(v, du + 1)
        q.push(v)
      }
    }
  }
  return dist
}

function lightningEdgeStats(nodeId, plainLinks) {
  let degree = 0
  let sumSats = 0
  let maxSats = 0
  for (const e of plainLinks) {
    if (e.source === nodeId || e.target === nodeId) {
      degree++
      const c = e.capacity_sats || 0
      sumSats += c
      maxSats = Math.max(maxSats, c)
    }
  }
  return { degree, sumSats, maxSats }
}

function lightningFarthestHop(distMap) {
  let m = 0
  for (const v of distMap.values()) m = Math.max(m, v)
  return m
}

let _lightningLabelMeasureCtx = null
function lightningLabelMeasureCtx() {
  if (_lightningLabelMeasureCtx === null) {
    const c = document.createElement("canvas")
    _lightningLabelMeasureCtx = c.getContext("2d")
  }
  return _lightningLabelMeasureCtx
}

/** Font size (px) scales with node radius; stays inside the circle when paired with truncation. */
function lightningNodeLabelFontPx(r) {
  return Math.max(4.25, Math.min(11, r * 0.5))
}

function lightningTruncateLabelToWidth(label, maxWidthPx, fontPx) {
  const raw = String(label ?? "").trim() || "—"
  const ell = "…"
  const ctx = lightningLabelMeasureCtx()
  if (!ctx || !(maxWidthPx > fontPx * 0.8)) return ell
  ctx.font = `600 ${fontPx}px system-ui, -apple-system, "Segoe UI", sans-serif`
  if (ctx.measureText(raw).width <= maxWidthPx) return raw
  let lo = 0
  let hi = raw.length
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2)
    const t = raw.slice(0, mid) + ell
    if (ctx.measureText(t).width <= maxWidthPx) lo = mid
    else hi = mid - 1
  }
  return lo > 0 ? raw.slice(0, lo) + ell : ell
}

function lightningLinkEndpointId(end) {
  return end && typeof end === "object" && "id" in end ? end.id : String(end ?? "")
}

/** Stable ±1 from pubkey pair so chords between the same two nodes curve consistently. */
function lightningEdgeCurveSign(sid, tid) {
  const a = sid < tid ? sid : tid
  const b = sid < tid ? tid : sid
  let h = 2166136261
  for (let i = 0; i < a.length; i++) h = Math.imul(h ^ a.charCodeAt(i), 16777619)
  for (let i = 0; i < b.length; i++) h = Math.imul(h ^ b.charCodeAt(i), 16777619)
  return h % 2 === 0 ? 1 : -1
}

/**
 * Quadratic Bezier from (sx,sy) to (tx,ty); bends sideways to reduce overlapping straight chords.
 * When `focusHubId` is set, edges incident to the hub use a gentler bend so spokes read as radial.
 */
function lightningQuadLinkPath(d, cxClamp, cyClamp, focusHubId) {
  const sx = cxClamp(d.source.x)
  const sy = cyClamp(d.source.y)
  const tx = cxClamp(d.target.x)
  const ty = cyClamp(d.target.y)
  const dx = tx - sx
  const dy = ty - sy
  const len = Math.hypot(dx, dy) || 1
  const mx = (sx + tx) / 2
  const my = (sy + ty) / 2
  const nx = -dy / len
  const ny = dx / len
  const sid = lightningLinkEndpointId(d.source)
  const tid = lightningLinkEndpointId(d.target)
  const sign = lightningEdgeCurveSign(sid, tid)
  const idx = d._curveIdx ?? 0
  const fan = 0.82 + 0.18 * ((idx % 9) / 8)
  const spoke =
    focusHubId != null && focusHubId !== "" && (sid === focusHubId || tid === focusHubId)
  const bendFactor = spoke ? 0.22 : 1
  const bend = 0.1 * len * sign * fan * bendFactor
  const cx = mx + nx * bend
  const cy = my + ny * bend
  return `M${sx},${sy}Q${cx},${cy} ${tx},${ty}`
}

export const LightningGraph = {
  mounted() {
    if (this.focusNodeId === undefined) this.focusNodeId = null
    if (this._edgeHoverId === undefined) this._edgeHoverId = null
    this.render()
  },
  updated() {
    this.render()
  },
  render() {
    if (this._cleanup) this._cleanup()

    const hook = this
    d3.select(hook.el).selectAll("*").remove()

    const raw = hook.el.dataset.graph
    if (!raw || raw === "null") {
      const msg = document.createElement("div")
      msg.className = "flex h-full items-center justify-center text-sm text-zinc-500"
      msg.textContent = "Data unavailable"
      hook.el.appendChild(msg)
      return
    }

    let payload
    try {
      payload = JSON.parse(raw)
    } catch (_) {
      const msg = document.createElement("div")
      msg.className = "flex h-full items-center justify-center text-sm text-zinc-500"
      msg.textContent = "Data unavailable"
      hook.el.appendChild(msg)
      return
    }

    const nodes = Array.isArray(payload.nodes) ? payload.nodes : []
    const rawEdges = Array.isArray(payload.edges) ? payload.edges : []
    if (nodes.length === 0) {
      const msg = document.createElement("div")
      msg.className = "flex h-full items-center justify-center text-sm text-zinc-500"
      msg.textContent = "Data unavailable"
      hook.el.appendChild(msg)
      return
    }

    const normPk = (pk) => String(pk || "").trim().toLowerCase()

    const width = Math.max(hook.el.clientWidth || 600, 280)
    const rect = hook.el.getBoundingClientRect()
    const height = Math.max(rect.height > 0 ? rect.height : 500, 300)

    const svg = d3
      .select(hook.el)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .style("display", "block")

    const caps = nodes.map((d) => d.capacity_sats || 0)
    const capMin = Math.min(...caps)
    const capMax = Math.max(...caps)
    const lo = Math.max(capMin, 1)
    const hi = Math.max(capMax, lo + 1)
    const rScale = d3.scaleLog().domain([lo, hi]).range([4, 18])

    const color = d3.scaleOrdinal(d3.schemeTableau10)

    const simulationNodes = nodes.map((d, i) => {
      const id = normPk(d.id)
      const r = rScale(Math.max(d.capacity_sats || 1, 1))
      const fontPx = lightningNodeLabelFontPx(r)
      const labelW = Math.max(2 * r - 4, fontPx * 1.1)
      return {
        ...d,
        id,
        r,
        color: color(i % 10),
        _lgFontPx: fontPx,
        _lgLabelText: lightningTruncateLabelToWidth(d.label, labelW, fontPx),
      }
    })

    const nodeIdSet = new Set(simulationNodes.map((d) => d.id))
    if (hook.focusNodeId && !nodeIdSet.has(hook.focusNodeId)) {
      hook.focusNodeId = null
    }

    const linkRows = rawEdges
      .map((e) => {
        const s = normPk(e.source)
        const t = normPk(e.target)
        const cap = e.capacity_sats ?? e.capacity ?? 0
        return { source: s, target: t, capacity_sats: cap }
      })
      .filter((e) => e.source && e.target && e.source !== e.target && nodeIdSet.has(e.source) && nodeIdSet.has(e.target))

    linkRows.forEach((e, i) => {
      e._curveIdx = i
    })

    const linksPlainSnapshot = linkRows.map((e) => ({
      source: e.source,
      target: e.target,
      capacity_sats: e.capacity_sats,
    }))

    const maxR = 20
    const cxClamp = (x) => Math.max(maxR, Math.min(width - maxR, x == null ? width / 2 : x))
    const cyClamp = (y) => Math.max(maxR, Math.min(height - maxR, y == null ? height / 2 : y))

    const cxMid = width / 2
    const cyMid = height / 2

    function seedDefaultPositions() {
      const jitter = 52
      for (const d of simulationNodes) {
        d.fx = null
        d.fy = null
        delete d._layer
        d.x = cxMid + (Math.random() - 0.5) * jitter
        d.y = cyMid + (Math.random() - 0.5) * jitter
        d.vx = 0
        d.vy = 0
      }
    }

    function seedFocusPositions(focusId) {
      const dist = lightningBfsLayers(focusId, linksPlainSnapshot)
      const far = lightningFarthestHop(dist)
      const outerLayer = far + 1

      for (const d of simulationNodes) {
        d.fx = null
        d.fy = null
      }

      const hub = simulationNodes.find((n) => n.id === focusId)
      if (hub) {
        hub.fx = cxMid
        hub.fy = cyMid
        hub.x = cxMid
        hub.y = cyMid
        hub.vx = 0
        hub.vy = 0
        hub._layer = 0
      }

      const byLayer = new Map()
      for (const d of simulationNodes) {
        if (d.id === focusId) continue
        const layer = dist.has(d.id) ? dist.get(d.id) : outerLayer
        d._layer = layer
        if (!byLayer.has(layer)) byLayer.set(layer, [])
        byLayer.get(layer).push(d)
      }

      const maxRing = Math.min(width, height) / 2 - 36
      const innerRing = 52
      const ringGap = 36

      const sortedLayers = Array.from(byLayer.keys()).sort((a, b) => a - b)
      for (const layer of sortedLayers) {
        const group = byLayer.get(layer)
        group.sort((a, b) => a.id.localeCompare(b.id))
        const r = Math.min(innerRing + (layer - 1) * ringGap, maxRing)
        group.forEach((d, i) => {
          const theta = (2 * Math.PI * i) / group.length - Math.PI / 2
          d.x = cxMid + r * Math.cos(theta)
          d.y = cyMid + r * Math.sin(theta)
          d.vx = 0
          d.vy = 0
        })
      }
    }

    const edgeCapMax = Math.max(1, ...linkRows.map((e) => e.capacity_sats || 0))

    const edgeSelection = svg
      .append("g")
      .attr("class", "edges")
      .style("pointer-events", "none")
      .selectAll("path")
      .data(linkRows)
      .join("path")
      .attr("fill", "none")
      .attr("stroke-linecap", "round")
      .attr("stroke-linejoin", "round")

    function refreshEdgeStyles() {
      const fid = hook.focusNodeId
      const hid = hook._edgeHoverId
      edgeSelection
        .attr("stroke", (d) => {
          const s = lightningLinkEndpointId(d.source)
          const t = lightningLinkEndpointId(d.target)
          if (fid && (s === fid || t === fid)) return "#e4e4e7"
          if (!fid && hid && (s === hid || t === hid)) return "#a1a1aa"
          return "#52525b"
        })
        .attr("stroke-opacity", (d) => {
          const s = lightningLinkEndpointId(d.source)
          const t = lightningLinkEndpointId(d.target)
          if (fid) return s === fid || t === fid ? 0.92 : 0.06
          if (hid) return s === hid || t === hid ? 0.88 : 0.07
          return 0.13
        })
        .attr("stroke-width", (d) => {
          const cap = d.capacity_sats || 0
          const base = 0.48 + (cap / edgeCapMax) * 2.45
          const s = lightningLinkEndpointId(d.source)
          const t = lightningLinkEndpointId(d.target)
          const hi =
            (fid && (s === fid || t === fid)) ||
            (!fid && hid && (s === hid || t === hid))
          return hi ? base * 1.5 : base * 0.55
        })
    }

    const layer = svg.append("g").attr("class", "lg-nodes")

    const nodeG = layer
      .selectAll("g.lg-node")
      .data(simulationNodes)
      .join("g")
      .attr("class", "lg-node")
      .attr("transform", (d) => `translate(${cxClamp(d.x)},${cyClamp(d.y)})`)
      .style("cursor", "pointer")

    nodeG
      .append("circle")
      .attr("r", (d) => d.r)
      .attr("fill", (d) => d.color)
      .attr("stroke", "none")

    nodeG
      .append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .attr("fill", "#fafafa")
      .attr("stroke", "#18181b")
      .attr("stroke-width", 0.45)
      .attr("paint-order", "stroke fill")
      .style("pointer-events", "none")
      .style("font-family", 'system-ui, -apple-system, "Segoe UI", sans-serif')
      .style("font-weight", "600")
      .style("font-size", (d) => `${d._lgFontPx}px`)
      .text((d) => d._lgLabelText)

    const hoverTip = d3
      .select(hook.el)
      .append("div")
      .classed("pointer-events-none", true)
      .classed("absolute", true)
      .classed("z-20", true)
      .classed("rounded", true)
      .classed("border", true)
      .classed("border-zinc-600", true)
      .classed("bg-zinc-800", true)
      .classed("px-2", true)
      .classed("py-1", true)
      .classed("text-xs", true)
      .classed("text-zinc-100", true)
      .classed("min-w-max", true)
      .classed("hidden", true)

    const focusPanel = d3
      .select(hook.el)
      .append("div")
      .classed("absolute", true)
      .classed("right-2", true)
      .classed("top-2", true)
      .classed("z-30", true)
      .classed("max-w-[min(22rem,calc(100%-1rem))]", true)
      .classed("rounded-lg", true)
      .classed("border", true)
      .classed("border-zinc-600", true)
      .classed("bg-zinc-900/95", true)
      .classed("p-3", true)
      .classed("text-xs", true)
      .classed("text-zinc-100", true)
      .classed("shadow-lg", true)
      .classed("hidden", true)
      .style("pointer-events", "auto")
      .on("click", (e) => e.stopPropagation())

    svg
      .insert("rect", ":first-child")
      .attr("width", width)
      .attr("height", height)
      .attr("fill", "transparent")
      .style("cursor", "default")
      .on("click", () => {
        if (!hook.focusNodeId) return
        hook.focusNodeId = null
        hook._edgeHoverId = null
        focusPanel.classed("hidden", true)
        hoverTip.classed("hidden", true)
        mountSimulation()
      })

    const el = hook.el

    function refreshHubStroke() {
      const fid = hook.focusNodeId
      nodeG
        .select("circle")
        .attr("stroke", (d) => (fid && d.id === fid ? "#fbbf24" : "none"))
        .attr("stroke-width", (d) => (fid && d.id === fid ? 2.5 : 0))
    }

    function fillFocusPanel(d) {
      const st = lightningEdgeStats(d.id, linksPlainSnapshot)
      const dist = lightningBfsLayers(d.id, linksPlainSnapshot)
      const reach = lightningFarthestHop(dist)
      const advBtc = ((d.capacity_sats || 0) / 1e8).toFixed(2)
      const adjBtc = (st.sumSats / 1e8).toFixed(2)
      const maxBtc = (st.maxSats / 1e8).toFixed(2)
      const pk = d.id
      const pkShort = pk.length > 24 ? `${pk.slice(0, 14)}…${pk.slice(-12)}` : pk

      focusPanel.html(`
        <div class="font-semibold text-sm text-zinc-100">${escapeHtmlLightning(d.label)}</div>
        <div class="mt-2 space-y-1 text-zinc-400">
          <div>Advertised capacity <span class="font-mono text-zinc-200">${advBtc} BTC</span></div>
          <div>Channels in this graph <span class="font-mono text-zinc-200">${st.degree}</span></div>
          <div>Adjacent liquidity <span class="font-mono text-zinc-200">${adjBtc} BTC</span> <span class="text-zinc-600">(sum of edges shown)</span></div>
          <div>Largest local channel <span class="font-mono text-zinc-200">${maxBtc} BTC</span></div>
          <div>Graph reach from here <span class="font-mono text-zinc-200">${reach}</span> <span class="text-zinc-600">hops</span></div>
        </div>
        <div class="mt-2 font-mono text-[10px] leading-snug text-zinc-500 break-all">${escapeHtmlLightning(pkShort)}</div>
        <button type="button" class="lg-clear-focus mt-3 w-full rounded border border-zinc-600 bg-zinc-800 px-2 py-1.5 text-xs font-medium text-zinc-200 hover:bg-zinc-700">
          Clear focus
        </button>
      `)

      focusPanel.select("button.lg-clear-focus").on("click", (e) => {
        e.stopPropagation()
        hook.focusNodeId = null
        hook._edgeHoverId = null
        focusPanel.classed("hidden", true)
        hoverTip.classed("hidden", true)
        mountSimulation()
      })
    }

    nodeG
      .on("mousemove", (event, d) => {
        if (!hook.focusNodeId) {
          hook._edgeHoverId = d.id
          refreshEdgeStyles()
        }
        if (hook.focusNodeId) return
        const containerRect = el.getBoundingClientRect()
        const mx = event.clientX - containerRect.left
        const my = event.clientY - containerRect.top
        const btc = ((d.capacity_sats || 0) / 1e8).toFixed(2)
        hoverTip
          .classed("hidden", false)
          .html(
            `<div class="font-semibold">${escapeHtmlLightning(d.label)}</div><div class="text-zinc-400">${btc} BTC capacity</div>`,
          )
          .style("left", `${mx + 14}px`)
          .style("top", `${my - 24}px`)
      })
      .on("mouseleave", () => {
        if (!hook.focusNodeId) {
          hook._edgeHoverId = null
          refreshEdgeStyles()
        }
        if (!hook.focusNodeId) hoverTip.classed("hidden", true)
      })
      .on("click", (event, d) => {
        event.stopPropagation()
        hook.focusNodeId = d.id
        hook._edgeHoverId = null
        hoverTip.classed("hidden", true)
        fillFocusPanel(d)
        focusPanel.classed("hidden", false)
        mountSimulation()
      })

    let sim = null

    function mountSimulation() {
      if (sim) {
        sim.stop()
        sim = null
      }

      const focusId = hook.focusNodeId
      if (focusId) {
        seedFocusPositions(focusId)
      } else {
        seedDefaultPositions()
      }

      const linkForce = d3
        .forceLink(linkRows)
        .id((n) => n.id)
        .distance((l) => {
          const sid = typeof l.source === "object" ? l.source.id : l.source
          const tid = typeof l.target === "object" ? l.target.id : l.target
          if (!focusId) return 122
          return sid === focusId || tid === focusId ? 64 : 112
        })
        .strength(focusId ? 0.52 : 0.44)

      const charge = d3.forceManyBody().strength(focusId ? -98 : -178)

      const center = d3.forceCenter(cxMid, cyMid).strength(focusId ? 0.05 : 0.11)

      const collide = d3.forceCollide((d) => d.r + 8).strength(0.94)

      sim = d3
        .forceSimulation(simulationNodes)
        .force("link", linkForce)
        .force("charge", charge)
        .force("center", center)
        .force("collide", collide)
        .alphaDecay(0.02)
        .alphaMin(focusId ? 0.028 : 0.035)

      if (focusId) {
        const maxRingPx = Math.min(width, height) / 2 - 28
        sim.force(
          "radial",
          d3
            .forceRadial(
              (d) => {
                if (d.id === focusId) return 0
                const layer = d._layer != null ? d._layer : 1
                return Math.min(44 + Math.max(0, layer - 1) * 34, maxRingPx)
              },
              cxMid,
              cyMid,
            )
            .strength(0.4),
        )
      } else {
        sim.force("radial", null)
      }

      sim.on("tick", () => {
        if (focusId) {
          const hub = simulationNodes.find((n) => n.id === focusId)
          if (hub) {
            hub.fx = cxMid
            hub.fy = cyMid
          }
        }
        edgeSelection.attr("d", (d) => lightningQuadLinkPath(d, cxClamp, cyClamp, focusId))
        nodeG.attr("transform", (d) => `translate(${cxClamp(d.x)},${cyClamp(d.y)})`)
        refreshEdgeStyles()
      })

      refreshHubStroke()
      sim.alpha(1).restart()
    }

    mountSimulation()

    if (hook.focusNodeId) {
      const sel = simulationNodes.find((n) => n.id === hook.focusNodeId)
      if (sel) {
        fillFocusPanel(sel)
        focusPanel.classed("hidden", false)
      }
    }

    hook._cleanup = () => {
      if (sim) sim.stop()
    }
  },
  destroyed() {
    if (this._cleanup) this._cleanup()
  },
}

export default {
  ScriptTypeChart,
  TxFlowGraph,
  RelativeTime,
  AddressQr,
  QrScan,
  LightningGraph,
}
