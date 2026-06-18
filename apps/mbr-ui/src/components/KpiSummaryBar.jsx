import { useKpis } from '../hooks/useKpis'

function fmtUSD(v) {
  if (v >= 1e6) return `$${(v / 1e6).toFixed(2)}M`
  return `$${(v / 1e3).toFixed(0)}K`
}
function fmtPct(v)   { return `${v.toFixed(1)}%` }
function fmtMiles(v) {
  if (v >= 1e6) return `${(v / 1e6).toFixed(2)}M`
  return `${(v / 1e3).toFixed(0)}K`
}
function fmtCPM(v)   { return `$${v.toFixed(3)}` }

function KpiCard({ label, value, delta, format }) {
  const formatted = value == null ? '—' : format(value)
  const deltaClass = delta == null ? '' : delta >= 0 ? 'positive' : 'negative'
  const sign       = delta == null ? '' : delta >= 0 ? '+' : ''

  return (
    <div className="kpi-card">
      <span className="kpi-label">{label}</span>
      <span className="kpi-value">{formatted}</span>
      {delta != null && (
        <span className={`kpi-delta ${deltaClass}`}>
          {sign}{delta.toFixed(1)}% vs prior
        </span>
      )}
    </div>
  )
}

export default function KpiSummaryBar({ period, region }) {
  const { data, isLoading, isError } = useKpis(period, region)

  if (!period || !region) return null

  if (isLoading) {
    return (
      <div className="kpi-bar kpi-bar--loading">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="kpi-card kpi-card--skeleton skeleton" />
        ))}
      </div>
    )
  }

  if (isError || !data) {
    return <div className="kpi-bar kpi-bar--error">KPI data unavailable</div>
  }

  const k = data.kpis ?? data

  return (
    <div className="kpi-bar">
      <KpiCard label="Revenue"          value={k.total_revenue}          delta={k.revenue_delta_pct}  format={fmtUSD}   />
      <KpiCard label="Total Miles"      value={k.total_miles}            delta={k.miles_delta_pct}    format={fmtMiles} />
      <KpiCard label="Total Cost"       value={k.total_cost}             delta={k.cost_delta_pct}     format={fmtUSD}   />
      <KpiCard label="Operating Margin" value={k.operating_margin_pct}   delta={k.margin_delta_pct}   format={fmtPct}   />
      <KpiCard label="Cost Per Mile"    value={k.cost_per_mile}          delta={k.cpm_delta_pct}      format={fmtCPM}   />
      <KpiCard label="On-Time %"        value={k.on_time_pct}            delta={k.on_time_delta_pct}  format={fmtPct}   />
      <KpiCard label="Fleet Util %"     value={k.fleet_utilization_pct}  delta={k.util_delta_pct}     format={fmtPct}   />
    </div>
  )
}
