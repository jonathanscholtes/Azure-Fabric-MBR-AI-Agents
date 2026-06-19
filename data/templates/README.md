# PowerPoint Templates

Place `mbr_template.pptx` here. The deployment process uploads it to Azure Blob Storage (`templates/mbr_template.pptx`), where the MCP server reads it at runtime.

## Placeholder names

The template uses **shape names** (not text box content) to identify fill targets. Rename shapes via Home → Arrange → Selection Pane.

| Shape name | Content |
|---|---|
| `title` | `LONGHAUL MBR — {Region} — {Period}` |
| `period` | Period label (e.g. "May 2025") |
| `region` | Region name (e.g. "North") |
| `total_revenue` | Formatted revenue string |
| `total_cost` | Formatted cost string |
| `operating_ratio` | Operating ratio percentage |
| `on_time_pct` | On-time delivery percentage |
| `fleet_utilization` | Fleet utilization percentage |
| `narrative` | Conversational agent narrative block |
| `key_drivers` | Bullet list of key drivers |

Shapes without a matching name are left unchanged.
