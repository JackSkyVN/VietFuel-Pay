import sys, io, asyncio
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import get_settings
from app.models import Customer
settings = get_settings()
engine = create_async_engine(settings.DATABASE_URL, echo=False)
F = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def run():
    async with F() as db:
        rows = (await db.execute(
            select(Customer.full_name, Customer.phone).order_by(Customer.created_at)
        )).all()
        with open('accounts_list.txt', 'w', encoding='utf-8') as f:
            f.write(f'Password for ALL accounts: Demo@1234\n')
            f.write(f'Total accounts: {len(rows)}\n')
            f.write('-' * 48 + '\n')
            f.write(f'{"#":<4}  {"Phone":<15}  Name\n')
            f.write('-' * 48 + '\n')
            for i, (name, phone) in enumerate(rows, 1):
                f.write(f'{i:<4}  {phone:<15}  {name}\n')
        print(f'Done – wrote {len(rows)} accounts to accounts_list.txt')
    await engine.dispose()

asyncio.run(run())
