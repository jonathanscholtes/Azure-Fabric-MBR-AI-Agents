import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
} from 'recharts';

export default function ServiceBarChart({ data }) {
  if (!data || data.length === 0) {
    return <div className="empty-state">No service data available.</div>;
  }

  return (
    <ResponsiveContainer width="100%" height={160}>
      <BarChart data={data} layout="vertical">
        <XAxis
          type="number"
          domain={[0, 100]}
          tick={{ fontSize: 11 }}
          tickFormatter={v => `${v}%`}
        />
        <YAxis
          type="category"
          dataKey="vehicle_type"
          tick={{ fontSize: 11 }}
          width={80}
        />
        <Tooltip formatter={v => [`${v}%`, 'On-Time']} />
        <Bar dataKey="pct" fill="var(--accent)" radius={[0, 4, 4, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
