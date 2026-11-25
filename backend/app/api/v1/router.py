"""Versioned v1 router registry."""

from fastapi import APIRouter

from app.modules.audit.router import router as audit_router
from app.modules.authentication.router import router as auth_router
from app.modules.bookings.quotations_router import quotations_router
from app.modules.bookings.router import bookings_router
from app.modules.crm.router import corporate_router, crm_router
from app.modules.customers.router import router as customers_router
from app.modules.dispatch.router import router as dispatch_router
from app.modules.drivers.router import router as drivers_router
from app.modules.finance.expense_router import expense_router
from app.modules.finance.router import router as finance_router
from app.modules.maintenance.router import router as maintenance_router
from app.modules.notifications.router import router as notifications_router
from app.modules.reports.router import dispatch_rec_router
from app.modules.reports.router import router as reports_router
from app.modules.reviews.router import router as reviews_router
from app.modules.services.router import router as services_router
from app.modules.tracking.router import router as tracking_router
from app.modules.trips.router import driver_router, incidents_router, trips_router
from app.modules.users.router import router as users_router
from app.modules.vehicles.router import admin_router as vehicles_admin_router
from app.modules.vehicles.router import public_router as vehicles_public_router

api_v1_router = APIRouter()
api_v1_router.include_router(auth_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(audit_router)
api_v1_router.include_router(services_router)
api_v1_router.include_router(vehicles_public_router)
api_v1_router.include_router(vehicles_admin_router)
api_v1_router.include_router(drivers_router)
api_v1_router.include_router(customers_router)
api_v1_router.include_router(bookings_router)
api_v1_router.include_router(quotations_router)
api_v1_router.include_router(dispatch_router)
api_v1_router.include_router(notifications_router)
api_v1_router.include_router(driver_router)
api_v1_router.include_router(trips_router)
api_v1_router.include_router(incidents_router)
api_v1_router.include_router(tracking_router)
api_v1_router.include_router(finance_router)
api_v1_router.include_router(expense_router)
api_v1_router.include_router(maintenance_router)
api_v1_router.include_router(corporate_router)
api_v1_router.include_router(crm_router)
api_v1_router.include_router(reviews_router)
api_v1_router.include_router(reports_router)
api_v1_router.include_router(dispatch_rec_router)
