# Google ADK + Qdrant

Docs: [Google ADK](https://qdrant.tech/documentation/frameworks/google-adk/)

## Run

`python3 commands/google-adk.py`

## Snippet

```python
from google.adk.agents import Agent
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from mcp import StdioServerParameters

root_agent = Agent(
    model="gemini-2.5-pro",
    name="qdrant_agent",
    instruction="Help users store and retrieve information using semantic search",
    tools=[
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command="uvx",
                    args=["mcp-server-qdrant"],
                    env={
                        "QDRANT_URL": "http://localhost:6333",
                        "COLLECTION_NAME": "my_collection",
                    },
                ),
                timeout=30,
            )
        )
    ],
)
```
