# Python Db2 SQLAlchemy Development Skill

## Description

Use this skill for developing Python applications that interact with IBM Db2 databases using SQLAlchemy ORM with the official IBM Db2 drivers (ibm_db and ibm_db_sa). Trigger this whenever the user mentions Python with Db2, SQLAlchemy with Db2, creating Python database applications with ORM, CRUD operations using SQLAlchemy, or needs help with ibm_db_sa for Db2 connectivity. Also use when they want to build REST APIs, data processing scripts, or any Python application that needs to connect to Db2 LUW databases using an ORM approach. This skill covers connection management, model definition, query execution, session handling, error management, migrations, and project structure best practices using SQLAlchemy with the native IBM Db2 drivers.

## Trigger Conditions

Activate this skill when the user's request involves:
- Python application development with Db2 databases
- SQLAlchemy ORM with IBM Db2
- ibm_db or ibm_db_sa Python modules
- Database models, schemas, or ORM patterns with Db2
- CRUD operations using SQLAlchemy with Db2
- Connection pooling and session management for Db2
- Database migrations or schema evolution with Alembic
- REST APIs or web applications using Flask/FastAPI with Db2
- Data processing, ETL, or analytics scripts connecting to Db2
- Any mention of "SQLAlchemy" combined with "Db2" or "IBM database"

## Core Principles

1. **Use Official IBM Drivers**: Always use `ibm_db` and `ibm_db_sa` for Db2 connectivity
2. **SQLAlchemy Best Practices**: Follow SQLAlchemy patterns for models, sessions, and queries
3. **Connection Management**: Implement proper connection pooling and session lifecycle
4. **Error Handling**: Provide comprehensive error handling for database operations
5. **Security**: Use parameterized queries, environment variables for credentials
6. **Performance**: Leverage connection pooling, lazy loading, and query optimization
7. **Maintainability**: Structure code with clear separation of concerns (models, repositories, services)

## Installation & Setup

### Required Dependencies

```python
# requirements.txt
ibm_db>=3.2.0
ibm_db_sa>=0.4.0
SQLAlchemy>=2.0.0
python-dotenv>=1.0.0
```

### Installation Commands

```bash
# Install IBM Db2 drivers and SQLAlchemy
pip install ibm_db ibm_db_sa SQLAlchemy python-dotenv

# For web applications, add:
pip install Flask  # or FastAPI

# For migrations:
pip install alembic
```

### Environment Configuration

```python
# .env
DB2_DATABASE=SAMPLE
DB2_HOSTNAME=localhost
DB2_PORT=50000
DB2_PROTOCOL=TCPIP
DB2_UID=db2inst1
DB2_PWD=your_password
DB2_SCHEMA=MYSCHEMA
```

## Connection Setup

### Basic Connection String

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

# Db2 connection string format
# ibm_db_sa://username:password@hostname:port/database
connection_string = (
    f"ibm_db_sa://{os.getenv('DB2_UID')}:{os.getenv('DB2_PWD')}"
    f"@{os.getenv('DB2_HOSTNAME')}:{os.getenv('DB2_PORT')}"
    f"/{os.getenv('DB2_DATABASE')}"
)

# Create engine with connection pooling
engine = create_engine(
    connection_string,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,  # Verify connections before using
    echo=False  # Set to True for SQL logging
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```

### Advanced Connection with Options

```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

# Connection string with additional parameters
connection_string = (
    f"ibm_db_sa://{os.getenv('DB2_UID')}:{os.getenv('DB2_PWD')}"
    f"@{os.getenv('DB2_HOSTNAME')}:{os.getenv('DB2_PORT')}"
    f"/{os.getenv('DB2_DATABASE')}"
    f"?CURRENTSCHEMA={os.getenv('DB2_SCHEMA')}"
)

# Engine with custom pooling configuration
engine = create_engine(
    connection_string,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=3600,  # Recycle connections after 1 hour
    pool_pre_ping=True,
    echo=False,
    connect_args={
        'CONNECTTIMEOUT': 30,
        'QUERYTIMEOUT': 60
    }
)
```

## Model Definition

### Base Model Setup

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import String, Integer, DateTime, Numeric, Text
from datetime import datetime
from typing import Optional

class Base(DeclarativeBase):
    """Base class for all models"""
    pass

# Alternative: Using declarative_base()
# from sqlalchemy.ext.declarative import declarative_base
# Base = declarative_base()
```

### Example Models

```python
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, Text
from sqlalchemy.orm import relationship
from datetime import datetime

class User(Base):
    __tablename__ = 'users'
    __table_args__ = {'schema': 'MYSCHEMA'}  # Specify schema
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    orders = relationship("Order", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}')>"

class Order(Base):
    __tablename__ = 'orders'
    __table_args__ = {'schema': 'MYSCHEMA'}
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('MYSCHEMA.users.id'), nullable=False)
    order_number = Column(String(20), unique=True, nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
    status = Column(String(20), default='pending')
    order_date = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Order(id={self.id}, order_number='{self.order_number}')>"

class OrderItem(Base):
    __tablename__ = 'order_items'
    __table_args__ = {'schema': 'MYSCHEMA'}
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    order_id = Column(Integer, ForeignKey('MYSCHEMA.orders.id'), nullable=False)
    product_name = Column(String(100), nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    
    # Relationships
    order = relationship("Order", back_populates="items")
    
    def __repr__(self):
        return f"<OrderItem(id={self.id}, product='{self.product_name}')>"
```

### Using Modern SQLAlchemy 2.0 Style

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from datetime import datetime
from typing import Optional, List

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = 'users'
    __table_args__ = {'schema': 'MYSCHEMA'}
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(100), unique=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    
    # Relationships with type hints
    orders: Mapped[List["Order"]] = relationship(back_populates="user", cascade="all, delete-orphan")
```

## Database Operations

### Session Management

```python
from contextlib import contextmanager

@contextmanager
def get_db_session():
    """Context manager for database sessions"""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        raise
    finally:
        session.close()

# Usage
with get_db_session() as session:
    user = User(username="john_doe", email="john@example.com")
    session.add(user)
    # Commit happens automatically on context exit
```

### CRUD Operations

```python
from sqlalchemy import select, update, delete
from sqlalchemy.orm import Session

class UserRepository:
    """Repository pattern for User operations"""
    
    @staticmethod
    def create(session: Session, username: str, email: str) -> User:
        """Create a new user"""
        user = User(username=username, email=email)
        session.add(user)
        session.flush()  # Get the ID without committing
        return user
    
    @staticmethod
    def get_by_id(session: Session, user_id: int) -> Optional[User]:
        """Get user by ID"""
        return session.get(User, user_id)
    
    @staticmethod
    def get_by_username(session: Session, username: str) -> Optional[User]:
        """Get user by username"""
        stmt = select(User).where(User.username == username)
        return session.execute(stmt).scalar_one_or_none()
    
    @staticmethod
    def get_all(session: Session, skip: int = 0, limit: int = 100) -> List[User]:
        """Get all users with pagination"""
        stmt = select(User).offset(skip).limit(limit)
        return list(session.execute(stmt).scalars())
    
    @staticmethod
    def update(session: Session, user_id: int, **kwargs) -> Optional[User]:
        """Update user fields"""
        user = session.get(User, user_id)
        if user:
            for key, value in kwargs.items():
                if hasattr(user, key):
                    setattr(user, key, value)
            user.updated_at = datetime.utcnow()
            session.flush()
        return user
    
    @staticmethod
    def delete(session: Session, user_id: int) -> bool:
        """Delete user by ID"""
        user = session.get(User, user_id)
        if user:
            session.delete(user)
            return True
        return False
    
    @staticmethod
    def search(session: Session, search_term: str) -> List[User]:
        """Search users by username or email"""
        stmt = select(User).where(
            (User.username.like(f"%{search_term}%")) |
            (User.email.like(f"%{search_term}%"))
        )
        return list(session.execute(stmt).scalars())
```

### Complex Queries

```python
from sqlalchemy import func, and_, or_, desc

class OrderRepository:
    
    @staticmethod
    def get_user_orders_with_items(session: Session, user_id: int):
        """Get user orders with eager loading of items"""
        from sqlalchemy.orm import joinedload
        
        stmt = (
            select(Order)
            .options(joinedload(Order.items))
            .where(Order.user_id == user_id)
            .order_by(desc(Order.order_date))
        )
        return list(session.execute(stmt).scalars().unique())
    
    @staticmethod
    def get_order_statistics(session: Session, user_id: int):
        """Get aggregated order statistics"""
        stmt = (
            select(
                func.count(Order.id).label('total_orders'),
                func.sum(Order.total_amount).label('total_spent'),
                func.avg(Order.total_amount).label('avg_order_value')
            )
            .where(Order.user_id == user_id)
        )
        result = session.execute(stmt).one()
        return {
            'total_orders': result.total_orders or 0,
            'total_spent': float(result.total_spent or 0),
            'avg_order_value': float(result.avg_order_value or 0)
        }
    
    @staticmethod
    def get_orders_by_status(session: Session, status: str, start_date=None, end_date=None):
        """Get orders filtered by status and date range"""
        stmt = select(Order).where(Order.status == status)
        
        if start_date:
            stmt = stmt.where(Order.order_date >= start_date)
        if end_date:
            stmt = stmt.where(Order.order_date <= end_date)
        
        return list(session.execute(stmt).scalars())
```

### Transactions

```python
def transfer_order(session: Session, order_id: int, from_user_id: int, to_user_id: int):
    """Transfer order between users with transaction"""
    try:
        # Verify order belongs to from_user
        order = session.get(Order, order_id)
        if not order or order.user_id != from_user_id:
            raise ValueError("Order not found or doesn't belong to user")
        
        # Verify to_user exists
        to_user = session.get(User, to_user_id)
        if not to_user:
            raise ValueError("Target user not found")
        
        # Transfer order
        order.user_id = to_user_id
        order.updated_at = datetime.utcnow()
        
        session.commit()
        return order
    except Exception as e:
        session.rollback()
        raise
```

## Error Handling

```python
from sqlalchemy.exc import (
    IntegrityError, 
    OperationalError, 
    DatabaseError,
    SQLAlchemyError
)
import logging

logger = logging.getLogger(__name__)

def safe_db_operation(func):
    """Decorator for safe database operations"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except IntegrityError as e:
            logger.error(f"Integrity error: {e}")
            raise ValueError("Database constraint violation")
        except OperationalError as e:
            logger.error(f"Operational error: {e}")
            raise ConnectionError("Database connection failed")
        except DatabaseError as e:
            logger.error(f"Database error: {e}")
            raise RuntimeError("Database operation failed")
        except SQLAlchemyError as e:
            logger.error(f"SQLAlchemy error: {e}")
            raise
    return wrapper

@safe_db_operation
def create_user_safe(session: Session, username: str, email: str):
    """Create user with error handling"""
    return UserRepository.create(session, username, email)
```

## Database Initialization

```python
# database/init_db.py
from sqlalchemy import create_engine, text
from models import Base
import os

def init_database():
    """Initialize database schema"""
    engine = create_engine(connection_string)
    
    # Create schema if it doesn't exist
    with engine.connect() as conn:
        schema = os.getenv('DB2_SCHEMA', 'MYSCHEMA')
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema}"))
        conn.commit()
    
    # Create all tables
    Base.metadata.create_all(bind=engine)
    print("Database initialized successfully")

def drop_database():
    """Drop all tables"""
    engine = create_engine(connection_string)
    Base.metadata.drop_all(bind=engine)
    print("Database dropped successfully")

if __name__ == "__main__":
    init_database()
```

## Project Structure

```
my_db2_app/
├── .env                      # Environment variables
├── .env.example              # Example environment file
├── .gitignore
├── requirements.txt
├── README.md
├── config/
│   ├── __init__.py
│   └── database.py          # Database configuration
├── models/
│   ├── __init__.py
│   ├── base.py              # Base model
│   ├── user.py              # User model
│   └── order.py             # Order model
├── repositories/
│   ├── __init__.py
│   ├── user_repository.py
│   └── order_repository.py
├── services/
│   ├── __init__.py
│   ├── user_service.py
│   └── order_service.py
├── database/
│   ├── __init__.py
│   ├── init_db.py           # Database initialization
│   └── seed_data.py         # Seed data
├── api/                      # For web applications
│   ├── __init__.py
│   └── routes.py
├── tests/
│   ├── __init__.py
│   ├── test_models.py
│   └── test_repositories.py
└── app.py                    # Main application
```

## Flask Integration Example

```python
# app.py
from flask import Flask, jsonify, request
from config.database import engine, SessionLocal, get_db_session
from repositories.user_repository import UserRepository
from models import Base

app = Flask(__name__)

# Initialize database
Base.metadata.create_all(bind=engine)

@app.route('/users', methods=['GET'])
def get_users():
    """Get all users"""
    with get_db_session() as session:
        users = UserRepository.get_all(session)
        return jsonify([{
            'id': u.id,
            'username': u.username,
            'email': u.email
        } for u in users])

@app.route('/users', methods=['POST'])
def create_user():
    """Create a new user"""
    data = request.get_json()
    
    with get_db_session() as session:
        try:
            user = UserRepository.create(
                session,
                username=data['username'],
                email=data['email']
            )
            return jsonify({
                'id': user.id,
                'username': user.username,
                'email': user.email
            }), 201
        except Exception as e:
            return jsonify({'error': str(e)}), 400

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get user by ID"""
    with get_db_session() as session:
        user = UserRepository.get_by_id(session, user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'id': user.id,
            'username': user.username,
            'email': user.email
        })

if __name__ == '__main__':
    app.run(debug=True)
```

## Testing

```python
# tests/test_repositories.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base, User
from repositories.user_repository import UserRepository

@pytest.fixture
def test_db():
    """Create test database"""
    engine = create_engine('ibm_db_sa://user:pass@localhost:50000/testdb')
    Base.metadata.create_all(bind=engine)
    TestSession = sessionmaker(bind=engine)
    session = TestSession()
    
    yield session
    
    session.close()
    Base.metadata.drop_all(bind=engine)

def test_create_user(test_db):
    """Test user creation"""
    user = UserRepository.create(test_db, "testuser", "test@example.com")
    assert user.id is not None
    assert user.username == "testuser"

def test_get_user_by_id(test_db):
    """Test getting user by ID"""
    user = UserRepository.create(test_db, "testuser", "test@example.com")
    test_db.commit()
    
    retrieved = UserRepository.get_by_id(test_db, user.id)
    assert retrieved is not None
    assert retrieved.username == "testuser"
```

## Performance Optimization

### Connection Pooling

```python
# Optimize connection pool settings
engine = create_engine(
    connection_string,
    pool_size=20,              # Number of connections to maintain
    max_overflow=10,           # Additional connections when pool is full
    pool_timeout=30,           # Timeout for getting connection
    pool_recycle=3600,         # Recycle connections after 1 hour
    pool_pre_ping=True         # Test connections before use
)
```

### Query Optimization

```python
from sqlalchemy.orm import joinedload, selectinload, subqueryload

# Eager loading to avoid N+1 queries
def get_users_with_orders(session: Session):
    """Get users with their orders in a single query"""
    stmt = (
        select(User)
        .options(joinedload(User.orders).joinedload(Order.items))
    )
    return list(session.execute(stmt).scalars().unique())

# Use selectinload for collections
def get_users_efficient(session: Session):
    stmt = select(User).options(selectinload(User.orders))
    return list(session.execute(stmt).scalars())
```

### Bulk Operations

```python
def bulk_insert_users(session: Session, users_data: List[dict]):
    """Bulk insert users efficiently"""
    session.bulk_insert_mappings(User, users_data)
    session.commit()

def bulk_update_users(session: Session, updates: List[dict]):
    """Bulk update users efficiently"""
    session.bulk_update_mappings(User, updates)
    session.commit()
```

## Common Patterns

### Repository Pattern

```python
from typing import Generic, TypeVar, Type, List, Optional
from sqlalchemy.orm import Session

T = TypeVar('T')

class BaseRepository(Generic[T]):
    """Generic repository for common CRUD operations"""
    
    def __init__(self, model: Type[T]):
        self.model = model
    
    def create(self, session: Session, **kwargs) -> T:
        instance = self.model(**kwargs)
        session.add(instance)
        session.flush()
        return instance
    
    def get_by_id(self, session: Session, id: int) -> Optional[T]:
        return session.get(self.model, id)
    
    def get_all(self, session: Session, skip: int = 0, limit: int = 100) -> List[T]:
        stmt = select(self.model).offset(skip).limit(limit)
        return list(session.execute(stmt).scalars())
    
    def delete(self, session: Session, id: int) -> bool:
        instance = session.get(self.model, id)
        if instance:
            session.delete(instance)
            return True
        return False
```

### Service Layer Pattern

```python
class UserService:
    """Business logic layer for users"""
    
    def __init__(self):
        self.repository = UserRepository()
    
    def register_user(self, username: str, email: str) -> dict:
        """Register a new user with validation"""
        with get_db_session() as session:
            # Check if username exists
            existing = self.repository.get_by_username(session, username)
            if existing:
                raise ValueError("Username already exists")
            
            # Create user
            user = self.repository.create(session, username, email)
            
            return {
                'id': user.id,
                'username': user.username,
                'email': user.email
            }
```

## Migration with Alembic

```bash
# Initialize Alembic
alembic init alembic

# Create migration
alembic revision --autogenerate -m "Create users table"

# Apply migration
alembic upgrade head

# Rollback migration
alembic downgrade -1
```

```python
# alembic/env.py configuration
from models import Base
target_metadata = Base.metadata

# In alembic.ini, set:
# sqlalchemy.url = ibm_db_sa://user:pass@localhost:50000/database
```

## Best Practices Summary

1. **Always use connection pooling** for production applications
2. **Use context managers** for session management
3. **Implement repository pattern** for data access layer
4. **Use eager loading** to avoid N+1 query problems
5. **Handle errors gracefully** with proper exception handling
6. **Use environment variables** for sensitive configuration
7. **Implement proper logging** for debugging and monitoring
8. **Write tests** for database operations
9. **Use transactions** for operations that must succeed or fail together
10. **Optimize queries** with proper indexing and query analysis

## Common Issues and Solutions

### Issue: Connection Pool Exhaustion
**Solution**: Increase pool size or ensure sessions are properly closed

```python
engine = create_engine(connection_string, pool_size=20, max_overflow=10)
```

### Issue: Schema Not Found
**Solution**: Specify schema in connection string or table args

```python
connection_string += "?CURRENTSCHEMA=MYSCHEMA"
# OR
__table_args__ = {'schema': 'MYSCHEMA'}
```

### Issue: Slow Queries
**Solution**: Use eager loading and query optimization

```python
stmt = select(User).options(joinedload(User.orders))
```

## References

- [python-ibmdbsa GitHub](https://github.com/ibmdb/python-ibmdbsa)
- [python-ibmdb GitHub](https://github.com/ibmdb/python-ibmdb)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [IBM Db2 Documentation](https://www.ibm.com/docs/en/db2)

## Example Projects

See the `examples/` directory for complete working examples:
- Basic CRUD application
- Flask REST API with Db2
- FastAPI application with SQLAlchemy
- Data processing pipeline