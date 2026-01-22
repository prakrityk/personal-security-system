"""
Base model for all database models
All models inherit from this Base class
"""
from sqlalchemy.ext.declarative import declarative_base

# Create the Base class
# All models will inherit from this
Base = declarative_base()