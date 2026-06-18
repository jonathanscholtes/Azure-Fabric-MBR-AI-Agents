const PERIODS = [
  'May 2025', 'Apr 2025', 'Mar 2025', 'Feb 2025', 'Jan 2025',
  'Dec 2024', 'Nov 2024', 'Oct 2024', 'Sep 2024', 'Aug 2024',
  'Jul 2024', 'Jun 2024', 'May 2024',
]

const REGIONS = [
  { label: 'All Regions', value: 'All' },
  { label: 'North',       value: 'North' },
  { label: 'South',       value: 'South' },
  { label: 'East',        value: 'East' },
  { label: 'West',        value: 'West' },
  { label: 'Central',     value: 'Central' },
]

export default function TopBar({ period, region, onPeriod, onRegion }) {
  return (
    <div className="topbar">
      <div className="topbar-title-block">
        <span className="topbar-title">MBR Creation &amp; Analysis</span>
        <span className="topbar-subtitle">
          Analyze performance and generate a management presentation that drives decisions.
        </span>
      </div>

      <div className="topbar-controls">
        <div>
          <label className="topbar-label">MBR Period</label>
          <select
            className="topbar-select"
            value={period}
            onChange={e => onPeriod(e.target.value)}
          >
            {PERIODS.map(p => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="topbar-label">Data Source</label>
          <select
            className="topbar-select"
            value={region}
            onChange={e => onRegion(e.target.value)}
          >
            {REGIONS.map(r => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </div>
      </div>
    </div>
  )
}
