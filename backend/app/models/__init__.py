"""
ORM Models – database table definitions.
"""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


# ── Enums ─────────────────────────────────────────────────────────────────────


class TransactionStatus(str, enum.Enum):
    PENDING = "PENDING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"
    COMPLETED = "COMPLETED"   # Used by Smart Wallet demo flow


class PaymentMethod(str, enum.Enum):
    LINKED_CARD = "LINKED_CARD"
    OFFLINE_QR = "OFFLINE_QR"
    MANUAL = "MANUAL"


class StaffRole(str, enum.Enum):
    CASHIER = "CASHIER"
    SUPERVISOR = "SUPERVISOR"
    MANAGER = "MANAGER"


# ── Models ────────────────────────────────────────────────────────────────────


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(200), unique=True, nullable=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    wallet_balance: Mapped[int] = mapped_column(Integer, default=0, nullable=False)  # VND cents-free integer
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    vehicles: Mapped[list["Vehicle"]] = relationship(back_populates="customer", cascade="all, delete-orphan")
    payment_methods: Mapped[list["LinkedPaymentMethod"]] = relationship(back_populates="customer", cascade="all, delete-orphan")
    transactions: Mapped[list["Transaction"]] = relationship(back_populates="customer")


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id", ondelete="CASCADE"))
    license_plate: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    make: Mapped[str | None] = mapped_column(String(80))
    model: Mapped[str | None] = mapped_column(String(80))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    customer: Mapped["Customer"] = relationship(back_populates="vehicles")


class LinkedPaymentMethod(Base):
    __tablename__ = "linked_payment_methods"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id", ondelete="CASCADE"))
    provider: Mapped[str] = mapped_column(String(80))          # e.g. "VISA", "MOMO", "ZALOPAY"
    masked_account: Mapped[str] = mapped_column(String(50))    # e.g. "**** **** **** 4242"
    gateway_token: Mapped[str] = mapped_column(String(512))    # Tokenised reference from gateway
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    customer: Mapped["Customer"] = relationship(back_populates="payment_methods")


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("customers.id", ondelete="SET NULL"), nullable=True
    )
    license_plate: Mapped[str] = mapped_column(String(20), index=True)
    fuel_liters: Mapped[float] = mapped_column(Float)
    amount_vnd: Mapped[float] = mapped_column(Float)
    status: Mapped[TransactionStatus] = mapped_column(
        Enum(TransactionStatus), default=TransactionStatus.PENDING
    )
    payment_method: Mapped[PaymentMethod] = mapped_column(Enum(PaymentMethod))
    gateway_reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
    geofence_validated: Mapped[bool] = mapped_column(Boolean, default=False)
    station_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    pump_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    customer: Mapped["Customer | None"] = relationship(back_populates="transactions")


class AiRecognitionLog(Base):
    """Stores every AI camera detection event for auditing and monitoring."""
    __tablename__ = "ai_recognition_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    license_plate: Mapped[str] = mapped_column(String(20), index=True)
    confidence_score: Mapped[float] = mapped_column(Float)         # 0.0 – 1.0
    raw_image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    station_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    camera_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    processed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class OfflineQrToken(Base):
    """Short-lived tokens for offline QR payment flow."""
    __tablename__ = "offline_qr_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    customer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("customers.id", ondelete="CASCADE"))
    token: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class GasStation(Base):
    """Gas station locations displayed on the customer map."""
    __tablename__ = "gas_stations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200))
    address: Mapped[str] = mapped_column(String(512))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(20), default="OPEN")  # OPEN | CLOSED | BUSY
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class StaffMember(Base):
    """Gas station staff who use the POS StaffDashboard."""
    __tablename__ = "staff_members"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    full_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    employee_code: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    role: Mapped[StaffRole] = mapped_column(Enum(StaffRole), default=StaffRole.CASHIER)
    station_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("gas_stations.id", ondelete="SET NULL"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    shift_transactions: Mapped[list["ShiftTransaction"]] = relationship(
        back_populates="staff", cascade="all, delete-orphan"
    )


class ShiftTransaction(Base):
    """A fuel-dispensing transaction recorded by a POS staff member."""
    __tablename__ = "shift_transactions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    staff_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("staff_members.id", ondelete="CASCADE")
    )
    license_plate: Mapped[str] = mapped_column(String(20), index=True)
    pump_number: Mapped[int] = mapped_column(Integer)
    amount_vnd: Mapped[int] = mapped_column(Integer)       # whole VND
    payment_method: Mapped[str] = mapped_column(String(40), default="CASH")  # CASH | QR | CARD
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)

    staff: Mapped["StaffMember"] = relationship(back_populates="shift_transactions")
