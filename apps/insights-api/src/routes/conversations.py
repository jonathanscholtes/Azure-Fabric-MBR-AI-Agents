"""Conversations endpoints — POST, GET list, GET by thread_id."""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, Request

from ..config import settings
from ..models import ConversationRequest, ConversationResponse, ThreadSummary, ConversationTurn
from ..storage import list_blobs, read_blob, upload_blob
from ..utils import parse_agent_json

logger = logging.getLogger("insights-api.routes.conversations")

router = APIRouter()

# In-memory map: { ui_thread_id: foundry_conversation_id }
# Suitable for PoC with a single ACA replica.
_session_conversations: dict[str, str] = {}


def _get_foundry_client(request: Request) -> Any:
    return request.app.state.foundry_client


def _agent_ref(agent_name: str) -> dict:
    """Build an agent_reference body. Handles optional 'name:version' format."""
    if ":" in agent_name:
        ref_name, ref_version = agent_name.rsplit(":", 1)
    else:
        ref_name, ref_version = agent_name, None
    ref: dict = {"type": "agent_reference", "name": ref_name}
    if ref_version:
        ref["version"] = ref_version
    return ref


async def _get_or_create_conversation(openai_client: Any, ui_thread_id: str) -> str:
    """Return existing Foundry conversation ID for this UI thread, or create a new one."""
    if ui_thread_id not in _session_conversations:
        conv = await openai_client.conversations.create()
        _session_conversations[ui_thread_id] = conv.id
        logger.info("Created Foundry conversation %s for UI thread %s", conv.id, ui_thread_id)
    return _session_conversations[ui_thread_id]


async def _run_conversational_agent(
    openai_client: Any,
    ui_thread_id: str,
    message: str,
    period: str,
    region: str,
) -> dict:
    """Invoke the Conversational Agent via the Responses protocol."""
    conv_id = await _get_or_create_conversation(openai_client, ui_thread_id)

    input_text = f"[Context: period='{period}', region='{region}']\n{message}"

    response = await openai_client.responses.create(
        input=input_text,
        conversation=conv_id,
        extra_body={"agent_reference": _agent_ref(settings.CONVERSATIONAL_AGENT_NAME)},
    )

    if response.status != "completed":
        raise RuntimeError(f"Agent run ended with status: {response.status}")

    return parse_agent_json(response.output_text or "")


def _parse_period_label(period: str) -> str:
    """Convert API period param (e.g. 'May2025') to display label (e.g. 'May 2025')."""
    if " " in period:
        return period
    for i, ch in enumerate(period):
        if ch.isdigit() and i > 0:
            return period[:i] + " " + period[i:]
    return period


@router.post("/conversations", response_model=ConversationResponse)
async def post_conversation(body: ConversationRequest, request: Request) -> ConversationResponse:
    """
    Send a user message to the Conversational Agent and return the structured response.
    Persists the conversation turn to Azure Storage.
    """
    client = _get_foundry_client(request)
    if client is None:
        raise HTTPException(status_code=503, detail="Foundry client not initialised")

    period_label = _parse_period_label(body.period)
    openai_client = client.get_openai_client()

    try:
        agent_result = await asyncio.wait_for(
            _run_conversational_agent(
                openai_client,
                body.thread_id,
                body.message,
                period_label,
                body.region,
            ),
            timeout=120.0,
        )
    except asyncio.TimeoutError as exc:
        raise HTTPException(status_code=504, detail="Conversational Agent timed out") from exc
    except Exception as exc:
        logger.exception("Foundry agent error: %s", exc)
        raise HTTPException(status_code=502, detail=f"Foundry agent error: {exc}") from exc

    # Persist conversation turn to Storage
    timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    turn_blob: dict = {
        "thread_id": body.thread_id,
        "period": period_label,
        "region": body.region,
        "timestamp": timestamp,
        "user_message": body.message,
        "agent_response": agent_result,
    }
    blob_path = f"{body.thread_id}/{timestamp}.json"
    try:
        upload_blob(
            "conversations",
            blob_path,
            json.dumps(turn_blob).encode("utf-8"),
            "application/json",
        )
    except Exception as exc:
        logger.warning("Failed to persist conversation turn to Storage: %s", exc)

    # Build response
    narrative = agent_result.get("narrative", "")
    key_drivers_raw = agent_result.get("key_drivers", [])
    analytics_raw = agent_result.get("analytics", {})

    from ..models import KeyDriver, AnalyticsPayload, RevenuePerformanceData, CostManagementData
    from ..models import OperationalEfficiencyData, ServicePerformanceData, BottomLineData

    key_drivers = []
    for kd in key_drivers_raw:
        try:
            key_drivers.append(KeyDriver(**kd))
        except Exception:
            pass

    analytics = AnalyticsPayload(
        revenue_performance=RevenuePerformanceData(
            **analytics_raw.get("revenue_performance", {})
        ) if "revenue_performance" in analytics_raw else RevenuePerformanceData(),
        cost_management=CostManagementData(
            **analytics_raw.get("cost_management", {})
        ) if "cost_management" in analytics_raw else CostManagementData(),
        operational_efficiency=OperationalEfficiencyData(
            **analytics_raw.get("operational_efficiency", {})
        ) if "operational_efficiency" in analytics_raw else OperationalEfficiencyData(),
        service_performance=ServicePerformanceData(
            **analytics_raw.get("service_performance", {})
        ) if "service_performance" in analytics_raw else ServicePerformanceData(),
        bottom_line=BottomLineData(
            **analytics_raw.get("bottom_line", {})
        ) if "bottom_line" in analytics_raw else BottomLineData(),
    )

    return ConversationResponse(
        thread_id=body.thread_id,
        narrative=narrative,
        key_drivers=key_drivers,
        analytics=analytics,
    )


@router.get("/conversations", response_model=dict)
async def list_conversations() -> dict:
    """
    List all conversation threads by enumerating blob prefixes in Storage.
    Returns first turn's user message as the thread summary.
    """
    try:
        all_blobs = list_blobs("conversations", "")
    except Exception as exc:
        logger.exception("Storage list_blobs failed: %s", exc)
        raise HTTPException(status_code=500, detail="Storage access failed") from exc

    thread_blobs: dict[str, list[str]] = {}
    for blob_name in all_blobs:
        parts = blob_name.split("/", 1)
        if len(parts) == 2:
            thread_id, _ = parts
            thread_blobs.setdefault(thread_id, []).append(blob_name)

    items: list[ThreadSummary] = []
    for thread_id, blobs in thread_blobs.items():
        blobs_sorted = sorted(blobs)
        first_blob = blobs_sorted[0]
        last_blob = blobs_sorted[-1]

        try:
            first_data = json.loads(read_blob("conversations", first_blob).decode("utf-8"))
            last_data = json.loads(read_blob("conversations", last_blob).decode("utf-8"))
        except Exception as exc:
            logger.warning("Failed to read conversation blob %s: %s", first_blob, exc)
            continue

        items.append(
            ThreadSummary(
                thread_id=thread_id,
                period=first_data.get("period", ""),
                region=first_data.get("region", ""),
                first_message=first_data.get("user_message", ""),
                turn_count=len(blobs),
                last_updated=last_data.get("timestamp", ""),
            )
        )

    items.sort(key=lambda t: t.last_updated, reverse=True)
    return {"items": [item.model_dump() for item in items]}


@router.get("/conversations/{thread_id}", response_model=dict)
async def get_conversation(thread_id: str) -> dict:
    """
    Return all turns for a specific conversation thread, ordered by timestamp.
    """
    prefix = f"{thread_id}/"
    try:
        blobs = list_blobs("conversations", prefix)
    except Exception as exc:
        logger.exception("Storage list_blobs failed: %s", exc)
        raise HTTPException(status_code=500, detail="Storage access failed") from exc

    if not blobs:
        raise HTTPException(status_code=404, detail=f"Conversation thread '{thread_id}' not found")

    blobs_sorted = sorted(blobs)
    turns: list[ConversationTurn] = []
    period = ""
    region = ""

    for blob_name in blobs_sorted:
        try:
            data = json.loads(read_blob("conversations", blob_name).decode("utf-8"))
        except Exception as exc:
            logger.warning("Failed to read conversation blob %s: %s", blob_name, exc)
            continue

        if not period:
            period = data.get("period", "")
        if not region:
            region = data.get("region", "")

        turns.append(
            ConversationTurn(
                timestamp=data.get("timestamp", ""),
                user_message=data.get("user_message", ""),
                agent_response=data.get("agent_response", {}),
            )
        )

    return {
        "thread_id": thread_id,
        "period": period,
        "region": region,
        "turns": [t.model_dump() for t in turns],
    }
