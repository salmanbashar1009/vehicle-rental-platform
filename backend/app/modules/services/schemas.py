"""Pydantic schemas for service categories and workflows."""

from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ServiceWorkflowResponse(BaseModel):
    """Workflow steps and form schema metadata."""

    model_config = ConfigDict(from_attributes=True)

    steps_json: list[str]
    form_schema_json: dict[str, Any]


class ServiceCategoryResponse(BaseModel):
    """Public service category response."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    slug: str
    name: str
    description: str
    requires_quote: bool
    is_active: bool
    display_order: int
    workflow: ServiceWorkflowResponse | None
