"""Presentations endpoints — POST generate, GET list, GET download."""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException, Request

from ..config import settings
from ..models import DeckSummary, PresentationRequest, PresentationResponse
from ..storage import get_blob_sas_url, list_blobs, read_blob, upload_blob
from ..utils import parse_agent_json

logger = logging.getLogger("mbr-api.routes.presentations")

router = APIRouter()


def _get_foundry_client(request: Request):
    return request.app.state.foundry_client


def _parse_period_label(period: str) -> str:
    if " " in period:
        return period
    for i, ch in enumerate(period):
        if ch.isdigit() and i > 0:
            return period[:i] + " " + period[i:]
    return period


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


async def _run_mbr_presentation_agent(
    openai_client: Any,
    period: str,
    region: str,
) -> dict:
    """One-shot Foundry agent call for MBR generation via the Responses protocol."""
    response = await openai_client.responses.create(
        input=f"Generate the MBR deck for {period}, region: {region}.",
        extra_body={"agent_reference": _agent_ref(settings.MBR_PRESENTATION_AGENT_NAME)},
    )

    if response.status != "completed":
        raise RuntimeError(f"Agent run ended with status: {response.status}")

    return parse_agent_json(response.output_text or "")


@router.post("/presentations", response_model=PresentationResponse)
async def generate_presentation(
    body: PresentationRequest, request: Request
) -> PresentationResponse:
    """
    Trigger the MBR Presentation Agent to generate a completed PowerPoint deck.
    Persists deck metadata to Storage and returns the response to the browser.
    """
    client = _get_foundry_client(request)
    if client is None:
        raise HTTPException(status_code=503, detail="Foundry client not initialised")

    period_label = _parse_period_label(body.period)
    openai_client = client.get_openai_client()

    try:
        agent_result = await asyncio.wait_for(
            _run_mbr_presentation_agent(openai_client, period_label, body.region),
            timeout=240.0,
        )
    except asyncio.TimeoutError as exc:
        raise HTTPException(status_code=504, detail="MBR Presentation Agent timed out") from exc
    except Exception as exc:
        logger.exception("MBR Presentation Agent error: %s", exc)
        raise HTTPException(
            status_code=502, detail=f"MBR Presentation Agent error: {exc}"
        ) from exc

    # Extract deck_id and thumbnail_urls from the agent result
    deck_id = agent_result.get("deck_id", str(uuid.uuid4()).replace("-", "")[:8])
    thumbnail_urls = agent_result.get("thumbnail_urls", [])
    deck_url = agent_result.get("deck_url", "")

    generated_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    period_slug = period_label.replace(" ", "")

    # Infer deck_blob path
    deck_blob = f"decks/{body.region}-{period_slug}-{deck_id}.pptx"

    # Save deck metadata blob
    metadata: dict = {
        "deck_id": deck_id,
        "period": period_label,
        "region": body.region,
        "generated_at": generated_at,
        "deck_blob": deck_blob,
        "thumbnail_urls": thumbnail_urls,
    }
    try:
        upload_blob(
            "decks-metadata",
            f"{deck_id}.json",
            json.dumps(metadata).encode("utf-8"),
            "application/json",
        )
    except Exception as exc:
        logger.warning("Failed to persist deck metadata to Storage: %s", exc)

    return PresentationResponse(
        deck_id=deck_id,
        period=period_label,
        region=body.region,
        generated_at=generated_at,
        deck_url=deck_url,
        thumbnail_urls=thumbnail_urls,
    )


@router.get("/presentations", response_model=dict)
async def list_presentations() -> dict:
    """
    List all previously generated decks by reading decks-metadata blobs from Storage.
    Ordered by generated_at descending.
    """
    try:
        blobs = list_blobs("decks-metadata", "")
    except Exception as exc:
        logger.exception("Storage list_blobs failed: %s", exc)
        raise HTTPException(status_code=500, detail="Storage access failed") from exc

    items: list[DeckSummary] = []
    for blob_name in blobs:
        if not blob_name.endswith(".json"):
            continue
        try:
            data = json.loads(read_blob("decks-metadata", blob_name).decode("utf-8"))
            items.append(
                DeckSummary(
                    deck_id=data["deck_id"],
                    period=data["period"],
                    region=data["region"],
                    generated_at=data["generated_at"],
                )
            )
        except Exception as exc:
            logger.warning("Failed to read deck metadata blob %s: %s", blob_name, exc)

    # Sort by generated_at descending
    items.sort(key=lambda d: d.generated_at, reverse=True)
    return {"items": [item.model_dump() for item in items]}


@router.get("/presentations/{deck_id}/download", response_model=dict)
async def download_presentation(deck_id: str) -> dict:
    """
    Return a short-lived SAS URL for downloading the completed .pptx.
    """
    # Read metadata to find the deck blob path
    try:
        metadata_data = read_blob("decks-metadata", f"{deck_id}.json")
        metadata = json.loads(metadata_data.decode("utf-8"))
    except Exception as exc:
        logger.exception("Failed to read deck metadata for %s: %s", deck_id, exc)
        raise HTTPException(status_code=404, detail=f"Deck '{deck_id}' not found") from exc

    deck_blob = metadata.get("deck_blob", "")
    if not deck_blob:
        raise HTTPException(status_code=404, detail=f"Deck blob path not found for '{deck_id}'")

    # deck_blob is e.g. "decks/Southwest-May2025-a1b2c3d4.pptx"
    # The container is "decks", the blob path within the container is the filename
    parts = deck_blob.split("/", 1)
    if len(parts) == 2:
        container, blob_path = parts
    else:
        container, blob_path = "decks", deck_blob

    try:
        sas_url = get_blob_sas_url(container, blob_path, expiry_hours=1)
    except Exception as exc:
        logger.exception("Failed to generate SAS URL for deck %s: %s", deck_id, exc)
        raise HTTPException(status_code=500, detail="Failed to generate download URL") from exc

    return {"url": sas_url}
