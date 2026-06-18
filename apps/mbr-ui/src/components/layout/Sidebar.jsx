import { NavLink, useNavigate } from 'react-router-dom'

function Icon({ d, size = 15 }) {
  return (
    <svg
      width={size} height={size} viewBox="0 0 24 24"
      fill="none" stroke="currentColor" strokeWidth="1.8"
      strokeLinecap="round" strokeLinejoin="round"
    >
      {(Array.isArray(d) ? d : [d]).map((path, i) => (
        <path key={i} d={path} />
      ))}
    </svg>
  )
}

const MAIN_NAV = [
  {
    label: 'Dashboard',
    to: '/dashboard',
    icon: ['M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z', 'M9 22V12h6v10'],
  },
  {
    label: 'Conversations',
    to: '/conversations',
    icon: ['M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z'],
  },
  {
    label: 'MBR Library',
    to: '/library',
    icon: ['M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z'],
  },
  {
    label: 'Presentations',
    to: '/presentations',
    icon: ['M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z', 'M14 2v6h6', 'M16 13H8', 'M16 17H8'],
  },
  {
    label: 'Client & Reports',
    to: '/reports',
    icon: ['M18 20V10', 'M12 20V4', 'M6 20v-6'],
  },
  {
    label: 'Settings',
    to: '/settings',
    icon: [
      'M12 15a3 3 0 100-6 3 3 0 000 6z',
      'M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z',
    ],
  },
]

const CONTENT_NAV = [
  { label: 'Fund Summary', to: '/dashboard', icon: ['M12 2L2 7l10 5 10-5-10-5z', 'M2 17l10 5 10-5', 'M2 12l10 5 10-5'] },
  { label: 'Region',       to: '/dashboard', icon: ['M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z'] },
  { label: 'Drivers',      to: '/dashboard', icon: ['M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2', 'M12 11a4 4 0 100-8 4 4 0 000 8z'] },
  { label: 'Client',       to: '/dashboard', icon: ['M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2', 'M9 11a4 4 0 100-8 4 4 0 000 8z', 'M23 21v-2a4 4 0 00-3-3.87', 'M16 3.13a4 4 0 010 7.75'] },
  { label: 'Links',        to: '/dashboard', icon: ['M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71', 'M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71'] },
]

export default function Sidebar() {
  const navigate = useNavigate()

  function handleNewMbr() {
    navigate('/dashboard')
    window.dispatchEvent(new CustomEvent('longhaul:reset'))
  }

  return (
    <aside className="sidebar">
      {/* Brand — logo image only (contains LONGHAUL INSIGHTS text) */}
      <div className="sidebar-logo">
        <img src="/trucking_logo.png" alt="LONGHAUL INSIGHTS" />
      </div>

      {/* New MBR */}
      <button className="sidebar-new-mbr-btn" onClick={handleNewMbr}>
        <Icon d={['M12 5v14', 'M5 12h14']} size={14} />
        + New MBR
      </button>

      {/* Main nav */}
      <nav>
        <ul className="sidebar-nav">
          {MAIN_NAV.map(item => (
            <li key={item.to + item.label}>
              <NavLink
                to={item.to}
                className={({ isActive }) => `sidebar-nav-item${isActive ? ' active' : ''}`}
              >
                <Icon d={item.icon} />
                {item.label}
              </NavLink>
            </li>
          ))}

          {/* Content section */}
          <li aria-hidden><hr /></li>
          <li><div className="sidebar-section-label">Content</div></li>
          {CONTENT_NAV.map(item => (
            <li key={item.label}>
              <span className="sidebar-nav-item sidebar-nav-item--sub">
                <Icon d={item.icon} size={13} />
                {item.label}
              </span>
            </li>
          ))}
        </ul>
      </nav>

      {/* User */}
      <div className="sidebar-user">
        <div className="sidebar-avatar">JS</div>
        <div className="sidebar-user-info">
          <span className="sidebar-user-name">Jonathan Scholtes</span>
          <span className="sidebar-user-role">Fleet Analyst</span>
        </div>
      </div>
    </aside>
  )
}
