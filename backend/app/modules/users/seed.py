"""Idempotent RBAC role and permission definitions + seeder."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.users.models import Permission, Role, RolePermission

PERMISSIONS_CATALOG: list[tuple[str, str]] = [
    ("users.read", "View staff users and roles"),
    ("users.write", "Create and modify staff users and roles"),
    ("audit.read", "View immutable audit logs"),
    ("bookings.read", "View all bookings and quotations"),
    ("bookings.write", "Create, quote, confirm, cancel, reschedule bookings"),
    ("fleet.read", "View vehicles, documents, and calendars"),
    ("fleet.write", "Create and modify vehicles and documents"),
    ("drivers.read", "View driver profiles and availability"),
    ("drivers.write", "Create and modify driver profiles"),
    ("dispatch.read", "View dispatch queue and eligible resources"),
    ("dispatch.write", "Assign and reassign vehicles and drivers"),
    ("trips.read", "View trips and incidents"),
    ("trips.write", "Manage trips and incidents"),
    ("tracking.read", "View live fleet GPS and authorized tracking"),
    ("finance.read", "View payments, invoices, expenses, and balances"),
    ("finance.write", "Record payments, refunds, and expense approvals"),
    ("reports.read", "View operational and financial reports"),
]

ROLE_MATRIX: dict[str, tuple[str, list[str]]] = {
    "owner": ("Owner / Super Admin", [p[0] for p in PERMISSIONS_CATALOG]),
    "booking_manager": (
        "Booking Manager",
        [
            "bookings.read",
            "bookings.write",
            "fleet.read",
            "drivers.read",
            "dispatch.read",
            "trips.read",
            "tracking.read",
            "finance.read",
            "reports.read",
        ],
    ),
    "fleet_manager": (
        "Fleet Manager",
        [
            "bookings.read",
            "fleet.read",
            "fleet.write",
            "drivers.read",
            "dispatch.read",
            "trips.read",
            "tracking.read",
            "reports.read",
        ],
    ),
    "dispatcher": (
        "Dispatcher",
        [
            "bookings.read",
            "fleet.read",
            "drivers.read",
            "dispatch.read",
            "dispatch.write",
            "trips.read",
            "trips.write",
            "tracking.read",
            "reports.read",
        ],
    ),
    "accountant": (
        "Accountant",
        ["bookings.read", "fleet.read", "finance.read", "finance.write", "reports.read"],
    ),
    "customer_support": (
        "Customer Support",
        [
            "bookings.read",
            "fleet.read",
            "drivers.read",
            "trips.read",
            "trips.write",
            "finance.read",
        ],
    ),
    "driver": ("Driver", []),
    "customer": ("Customer", []),
}


async def seed_roles_and_permissions(session: AsyncSession) -> None:
    """Idempotently seed all 8 platform roles and permission mappings."""
    existing_perms = {
        p.code: p for p in (await session.execute(select(Permission))).scalars().all()
    }
    for code, desc in PERMISSIONS_CATALOG:
        if code not in existing_perms:
            perm = Permission(code=code, description=desc)
            session.add(perm)
            await session.flush()
            existing_perms[code] = perm

    existing_roles = {r.slug: r for r in (await session.execute(select(Role))).scalars().all()}
    for slug, (name, perm_codes) in ROLE_MATRIX.items():
        role = existing_roles.get(slug)
        if role is None:
            role = Role(slug=slug, name=name)
            session.add(role)
            await session.flush()
            existing_roles[slug] = role

        current_perm_ids = set(
            (
                await session.execute(
                    select(RolePermission.permission_id).where(RolePermission.role_id == role.id)
                )
            ).scalars()
        )
        for code in perm_codes:
            perm_id = existing_perms[code].id
            if perm_id not in current_perm_ids:
                session.add(RolePermission(role_id=role.id, permission_id=perm_id))
                current_perm_ids.add(perm_id)
    await session.flush()
