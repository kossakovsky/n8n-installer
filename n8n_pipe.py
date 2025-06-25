"""
title: n8n Pipe Function
author: Cole Medin
author_url: https://www.youtube.com/@ColeMedin
version: 0.1.1

This module defines a Pipe class that utilizes N8N for an Agent.
Enhanced to work with the comprehensive n8n-installer setup including 
AppFlowy, Affine, and other knowledge management integrations.
"""

from typing import Optional, Callable, Awaitable
from pydantic import BaseModel, Field
import os
import time
import requests

def extract_event_info(event_emitter) -> tuple[Optional[str], Optional[str]]:
    if not event_emitter or not event_emitter.__closure__:
        return None, None
    for cell in event_emitter.__closure__:
        if isinstance(request_info := cell.cell_contents, dict):
            chat_id = request_info.get("chat_id")
            message_id = request_info.get("message_id")
            return chat_id, message_id
    return None, None

class Pipe:
    class Valves(BaseModel):
        n8n_url: str = Field(
            default="https://n8n.[your domain].com/webhook/[your webhook URL]",
            description="Your n8n webhook URL for processing requests"
        )
        n8n_bearer_token: str = Field(
            default="...",
            description="Bearer token for n8n webhook authentication"
        )
        input_field: str = Field(
            default="chatInput",
            description="Field name for input in n8n workflow"
        )
        response_field: str = Field(
            default="output",
            description="Field name for response from n8n workflow"
        )
        emit_interval: float = Field(
            default=2.0, 
            description="Interval in seconds between status emissions"
        )
        enable_status_indicator: bool = Field(
            default=True, 
            description="Enable or disable status indicator emissions"
        )
        enable_knowledge_integration: bool = Field(
            default=False,
            description="Enable integration with AppFlowy/Affine knowledge bases"
        )
        appflowy_url: str = Field(
            default="https://appflowy.[your domain].com",
            description="AppFlowy instance URL for knowledge management integration"
        )
        affine_url: str = Field(
            default="https://affine.[your domain].com",
            description="Affine instance URL for collaborative workspace integration"
        )

    def __init__(self):
        self.type = "pipe"
        self.id = "n8n_pipe"
        self.name = "N8N Pipe Enhanced"
        self.valves = self.Valves()
        self.last_emit_time = 0
        pass

    async def emit_status(
        self,
        __event_emitter__: Callable[[dict], Awaitable[None]],
        level: str,
        message: str,
        done: bool,
    ):
        current_time = time.time()
        if (
            __event_emitter__
            and self.valves.enable_status_indicator
            and (
                current_time - self.last_emit_time >= self.valves.emit_interval or done
            )
        ):
            await __event_emitter__(
                {
                    "type": "status",
                    "data": {
                        "status": "complete" if done else "in_progress",
                        "level": level,
                        "description": message,
                        "done": done,
                    },
                }
            )
            self.last_emit_time = current_time

    async def check_knowledge_sources(self, query: str) -> dict:
        """
        Check if the query relates to knowledge management and provide context
        from AppFlowy or Affine if enabled.
        """
        if not self.valves.enable_knowledge_integration:
            return {"knowledge_context": None, "sources": []}
        
        knowledge_context = {
            "appflowy_available": bool(self.valves.appflowy_url and self.valves.appflowy_url != "https://appflowy.[your domain].com"),
            "affine_available": bool(self.valves.affine_url and self.valves.affine_url != "https://affine.[your domain].com"),
            "query_keywords": self._extract_knowledge_keywords(query),
            "sources": []
        }
        
        # Add context about available knowledge management systems
        if knowledge_context["appflowy_available"]:
            knowledge_context["sources"].append({
                "type": "appflowy",
                "url": self.valves.appflowy_url,
                "description": "AppFlowy knowledge management system"
            })
        
        if knowledge_context["affine_available"]:
            knowledge_context["sources"].append({
                "type": "affine", 
                "url": self.valves.affine_url,
                "description": "Affine collaborative workspace"
            })
        
        return knowledge_context

    def _extract_knowledge_keywords(self, query: str) -> list:
        """Extract keywords that might relate to knowledge management."""
        knowledge_keywords = [
            "document", "note", "wiki", "knowledge", "project", "task",
            "team", "collaborate", "workspace", "database", "report",
            "meeting", "plan", "strategy", "research", "analysis"
        ]
        
        query_lower = query.lower()
        found_keywords = [keyword for keyword in knowledge_keywords if keyword in query_lower]
        return found_keywords

    async def pipe(
        self,
        body: dict,
        __user__: Optional[dict] = None,
        __event_emitter__: Callable[[dict], Awaitable[None]] = None,
        __event_call__: Callable[[dict], Awaitable[dict]] = None,
    ) -> Optional[dict]:
        await self.emit_status(
            __event_emitter__, "info", "🚀 Calling N8N Workflow...", False
        )
        
        chat_id, _ = extract_event_info(__event_emitter__)
        messages = body.get("messages", [])

        # Verify a message is available
        if messages:
            question = messages[-1]["content"]
            
            # Check for knowledge management context
            knowledge_context = await self.check_knowledge_sources(question)
            
            try:
                await self.emit_status(
                    __event_emitter__, "info", "🔄 Processing with n8n...", False
                )
                
                # Invoke N8N workflow
                headers = {
                    "Authorization": f"Bearer {self.valves.n8n_bearer_token}",
                    "Content-Type": "application/json",
                }
                
                payload = {
                    "sessionId": f"{chat_id}",
                    "knowledge_context": knowledge_context if self.valves.enable_knowledge_integration else None
                }
                payload[self.valves.input_field] = question
                
                await self.emit_status(
                    __event_emitter__, "info", "📡 Sending request to n8n...", False
                )
                
                response = requests.post(
                    self.valves.n8n_url, json=payload, headers=headers, timeout=30
                )
                
                if response.status_code == 200:
                    n8n_response = response.json()[self.valves.response_field]
                    
                    # Add knowledge management context to response if available
                    if knowledge_context and knowledge_context.get("sources"):
                        knowledge_info = "\n\n---\n💡 **Available Knowledge Sources:**\n"
                        for source in knowledge_context["sources"]:
                            knowledge_info += f"• [{source['description']}]({source['url']})\n"
                        n8n_response += knowledge_info
                    
                    await self.emit_status(
                        __event_emitter__, "success", "✅ Response received from n8n", False
                    )
                    
                else:
                    raise Exception(f"Error: {response.status_code} - {response.text}")

                # Set assistant message with chain reply
                body["messages"].append({"role": "assistant", "content": n8n_response})
                
            except requests.exceptions.Timeout:
                error_msg = "⏰ Request to n8n timed out. Please try again."
                await self.emit_status(
                    __event_emitter__,
                    "error",
                    error_msg,
                    True,
                )
                body["messages"].append({"role": "assistant", "content": error_msg})
                return {"error": "timeout"}
                
            except Exception as e:
                error_msg = f"❌ Error during n8n workflow execution: {str(e)}"
                await self.emit_status(
                    __event_emitter__,
                    "error",
                    error_msg,
                    True,
                )
                body["messages"].append({"role": "assistant", "content": error_msg})
                return {"error": str(e)}
        # If no message is available alert user
        else:
            error_msg = "❌ No messages found in the request body"
            await self.emit_status(
                __event_emitter__,
                "error",
                error_msg,
                True,
            )
            body["messages"].append(
                {
                    "role": "assistant",
                    "content": error_msg,
                }
            )

        await self.emit_status(__event_emitter__, "success", "🎉 Complete", True)
        return body
