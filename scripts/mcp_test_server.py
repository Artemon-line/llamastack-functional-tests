"""
Minimal MCP test server for functional tests.

Start before running MCP notebook tests:
    uv run python scripts/mcp_test_server.py

Runs on http://127.0.0.1:8090/mcp (streamable-http transport).
Set MCP_SERVER_PORT to change the port.
"""

import os
from mcp.server.fastmcp import FastMCP

port = int(os.environ.get("MCP_SERVER_PORT", "8090"))
app = FastMCP("test-server", port=port)


@app.tool()
def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b


@app.tool()
def multiply(a: int, b: int) -> int:
    """Multiply two numbers."""
    return a * b


if __name__ == "__main__":
    print(f"Starting MCP test server on http://127.0.0.1:{port}/mcp")
    app.run(transport="streamable-http")
