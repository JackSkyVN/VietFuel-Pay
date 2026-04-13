import asyncio, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import get_settings
from app.models import (Customer, Vehicle, LinkedPaymentMethod,
                        Transaction, AiRecognitionLog, OfflineQrToken)

settings = get_settings()
engine = create_async_engine(settings.DATABASE_URL, echo=False)
F = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def check():
    async with F() as db:
        for M in [Customer, Vehicle, LinkedPaymentMethod,
                  Transaction, AiRecognitionLog, OfflineQrToken]:
            n = (await db.execute(select(func.count()).select_from(M))).scalar()
            print(f"{M.__tablename__}: {n} rows")
    await engine.dispose()

asyncio.run(check())
