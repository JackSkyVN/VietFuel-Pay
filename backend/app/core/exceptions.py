"""
Custom application exceptions and FastAPI exception handlers.
"""
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class SmartRefuelException(Exception):
    """Base exception class."""

    def __init__(self, detail: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        self.detail = detail
        self.status_code = status_code
        super().__init__(detail)


class NotFoundException(SmartRefuelException):
    def __init__(self, resource: str = "Resource"):
        super().__init__(f"{resource} not found.", status.HTTP_404_NOT_FOUND)


class GeofenceViolationException(SmartRefuelException):
    def __init__(self):
        super().__init__(
            "Geofence validation failed: vehicle is not within the station perimeter.",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        )


class PaymentGatewayException(SmartRefuelException):
    def __init__(self, gateway_msg: str = "Unknown error"):
        super().__init__(
            f"Payment gateway error: {gateway_msg}",
            status.HTTP_502_BAD_GATEWAY,
        )


class DuplicateEntryException(SmartRefuelException):
    def __init__(self, resource: str = "Record"):
        super().__init__(f"{resource} already exists.", status.HTTP_409_CONFLICT)


class UnauthorizedException(SmartRefuelException):
    def __init__(self, detail: str = "Authentication required."):
        super().__init__(detail, status.HTTP_401_UNAUTHORIZED)


# ── Handler registration ──────────────────────────────────────────────────────

def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(SmartRefuelException)
    async def smart_refuel_exception_handler(
        request: Request, exc: SmartRefuelException
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"success": False, "detail": exc.detail},
        )
