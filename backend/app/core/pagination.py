"""Shared pagination query parameters and response envelope."""

import math

from pydantic import BaseModel, Field


class PaginationParams(BaseModel):
    """Validated pagination query parameters."""

    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)

    @property
    def offset(self) -> int:
        """Compute SQL OFFSET."""
        return (self.page - 1) * self.page_size


class PaginatedResponse[T](BaseModel):
    """Standard paginated API response envelope."""

    items: list[T]
    page: int
    page_size: int
    total_items: int
    total_pages: int

    @classmethod
    def create(
        cls,
        *,
        items: list[T],
        page: int,
        page_size: int,
        total_items: int,
    ) -> "PaginatedResponse[T]":
        """Build paginated response computing total_pages safely."""
        total_pages = math.ceil(total_items / page_size) if total_items > 0 else 0
        return cls(
            items=items,
            page=page,
            page_size=page_size,
            total_items=total_items,
            total_pages=total_pages,
        )
