"""FastMCP tool server for LONGHAUL MBR — PowerPoint generation and deck library.

Runs on ACA internal ingress (port 80). Accessible only by Foundry agents.

Tools:
  - get_template_slides   (read)   — pre-rendered template slide thumbnails
  - fill_presentation_template     (write)  — fill pptx template + upload deck + generate thumbnails
  - get_deck_url      (read)   — SAS URL for a completed deck
  - list_decks        (read)   — list generated decks from metadata blobs
"""

from __future__ import annotations

import logging
import os

from mcp.server.fastmcp import FastMCP

from .tools.powerpoint_tools import register_powerpoint_tools
from .tools.library_tools import register_library_tools

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("presentation-tools")

host = os.environ.get("HOST", "0.0.0.0")
port = int(os.environ.get("PORT", "80"))

mcp = FastMCP(
    name="presentation-tools",
    host=host,
    port=port,
    stateless_http=True,
)

register_powerpoint_tools(mcp)
register_library_tools(mcp)


def main() -> None:
    logger.info("Starting MCP server on %s:%s", host, port)
    mcp.run(transport="streamable-http")


if __name__ == "__main__":
    main()
