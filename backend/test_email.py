from pydantic import BaseModel, EmailStr

class TestModel(BaseModel):
    email: EmailStr

m = TestModel(email="test@example.com")
print(m)
