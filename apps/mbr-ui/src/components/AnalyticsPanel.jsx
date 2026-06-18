import { useAnalytics } from '../hooks/useAnalytics'
import RevenueLineChart from './charts/RevenueLineChart'
import EfficiencyDonut from './charts/EfficiencyDonut'
import ServiceBarChart from './charts/ServiceBarChart'

export default function AnalyticsPanel({ period, region }) {
  const { data, isLoading, isError } = useAnalytics(period, region)

  if (!period || !region) return null

  if (isLoading) {
    return (
      <>
        {[80, 120, 80, 100].map((h, i) => (
          <div key={i} className="analytics-card skeleton" style={{ minHeight: h }} />
        ))}
      </>
    )
  }

  if (isError || !data) {
    return (
      <div className="analytics-card">
        <p className="analytics-narrative" style={{ color: 'var(--muted)' }}>
          Analytics unavailable — ensure the API is reachable and the Lakehouse is seeded.
        </p>
      </div>
    )
  }

  return (
    <>
      <div className="analytics-card">
        <div className="analytics-card-title">Revenue Performance</div>
        <RevenueLineChart data={data.revenue_trend} />
        {data.revenue_narrative && (
          <p className="analytics-narrative" style={{ marginTop: 10 }}>{data.revenue_narrative}</p>
        )}
      </div>

      <div className="analytics-card">
        <div className="analytics-card-title">Fleet Efficiency</div>
        <div className="analytics-donut-row">
          {data.fleet_utilization_pct != null && (
            <div className="analytics-donut-item">
              <EfficiencyDonut value={data.fleet_utilization_pct} />
              <span className="analytics-donut-label">Fleet Util.</span>
            </div>
          )}
          {data.on_time_pct != null && (
            <div className="analytics-donut-item">
              <EfficiencyDonut value={data.on_time_pct} />
              <span className="analytics-donut-label">On-Time</span>
            </div>
          )}
          {data.loaded_mile_pct != null && (
            <div className="analytics-donut-item">
              <EfficiencyDonut value={data.loaded_mile_pct} />
              <span className="analytics-donut-label">Loaded Mile %</span>
            </div>
          )}
        </div>
      </div>

      {data.cost_breakdown && (
        <div className="analytics-card">
          <div className="analytics-card-title">Cost Management</div>
          {Object.entries(data.cost_breakdown).map(([k, v]) => (
            <div key={k} className="analytics-metric-row">
              <span className="analytics-metric-label">{k}</span>
              <span className="analytics-metric-value">{typeof v === 'number' ? `$${(v/1e6).toFixed(2)}M` : v}</span>
            </div>
          ))}
        </div>
      )}

      {data.on_time_by_vehicle && (
        <div className="analytics-card">
          <div className="analytics-card-title">On-Time by Vehicle Type</div>
          <ServiceBarChart data={data.on_time_by_vehicle} />
        </div>
      )}

      {data.bottom_line && (
        <div className="analytics-card" style={{ borderColor: 'rgba(34,197,94,.3)' }}>
          <div className="analytics-card-title" style={{ color: 'var(--accent)' }}>Bottom Line</div>
          <p className="analytics-narrative">{data.bottom_line}</p>
        </div>
      )}
    </>
  )
}
