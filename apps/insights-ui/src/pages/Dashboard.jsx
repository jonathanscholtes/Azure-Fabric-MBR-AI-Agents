import KpiSummaryBar from '../components/KpiSummaryBar'
import ConversationPanel from '../components/ConversationPanel'
import AnalyticsPanel from '../components/AnalyticsPanel'
import PresentationPanel from '../components/PresentationPanel'
import { useConversation } from '../hooks/useConversation'

const MON_ABBR = { Jan:1, Feb:2, Mar:3, Apr:4, May:5, Jun:6, Jul:7, Aug:8, Sep:9, Oct:10, Nov:11, Dec:12 }
const FULL_MON = ['','January','February','March','April','May','June','July','August','September','October','November','December']

function periodDateRange(period) {
  const parts = period.split(' ')
  if (parts.length !== 2) return period
  const mon = MON_ABBR[parts[0]]
  const yr  = parseInt(parts[1])
  if (!mon || !yr) return period
  const lastDay = new Date(yr, mon, 0).getDate()
  return `${FULL_MON[mon]} 1 – ${FULL_MON[mon]} ${lastDay}, ${yr}`
}

export default function Dashboard({ period, region }) {
  const { messages, isPending, send } = useConversation(period, region)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0 }}>

      {/* ── Executive Summary header with trucking photo ── */}
      <div className="report-header">
        <img src="/trucking_photo.png" alt="" className="report-header-photo" />
        <div className="report-header-overlay" />
        <div className="report-header-content">
          <div className="report-header-title-block">
            <span className="report-header-label">LONGHAUL INSIGHTS</span>
            <span className="report-header-title">Executive Summary</span>
            <span className="report-header-subtitle">
              {periodDateRange(period)} &nbsp;&middot;&nbsp; {region} Region
            </span>
          </div>
        </div>
      </div>

      {/* ── KPI bar ── */}
      <KpiSummaryBar period={period} region={region} />

      {/* ── Three panels ── */}
      <div className="three-panel" style={{ flex: 1, minHeight: 0 }}>

        {/* Conversational Insights */}
        <div className="panel-col">
          <div className="panel-col-header">
            <span className="panel-col-title">Conversational Insights</span>
            {messages.length > 0 && (
              <span className="panel-col-badge">{messages.length}</span>
            )}
          </div>
          <div className="panel-col-body panel-col-body--conversation">
            <ConversationPanel
              period={period}
              region={region}
              messages={messages}
              isPending={isPending}
              onSend={send}
            />
          </div>
        </div>

        {/* Analytics & Reasoning */}
        <div className="panel-col">
          <div className="panel-col-header">
            <span className="panel-col-title">Analytics &amp; Reasoning</span>
            <button className="panel-col-link">View Full Analysis →</button>
          </div>
          <div className="panel-col-body">
            <AnalyticsPanel period={period} region={region} />
          </div>
        </div>

        {/* MBR Presentation */}
        <div className="panel-col">
          <div className="panel-col-header">
            <span className="panel-col-title">MBR Presentation</span>
          </div>
          <div className="panel-col-body">
            <PresentationPanel period={period} region={region} />
          </div>
        </div>

      </div>
    </div>
  )
}
