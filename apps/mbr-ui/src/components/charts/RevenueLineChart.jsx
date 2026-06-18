import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';

export default function RevenueLineChart({ data }) {
  if (!data || data.length === 0) {
    return <div className="empty-state">No trend data available.</div>;
  }

  return (
    <ResponsiveContainer width="100%" height={160}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
        <XAxis dataKey="period" tick={{ fontSize: 11 }} />
        <YAxis
          tickFormatter={v => `$${v.toFixed(1)}M`}
          tick={{ fontSize: 11 }}
          width={52}
        />
        <Tooltip formatter={v => [`$${v.toFixed(2)}M`, 'Revenue']} />
        <Line
          type="monotone"
          dataKey="revenue"
          stroke="var(--accent)"
          strokeWidth={2}
          dot={false}
          activeDot={{ r: 4 }}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
