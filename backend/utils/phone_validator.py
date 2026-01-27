"""
Phone number validation and formatting utility
Standardizes phone numbers to +977XXXXXXXXXX format for Nepal
"""
import re
from fastapi import HTTPException


def clean_phone_number(phone: str) -> str:
    """
    Clean and format phone number to +977XXXXXXXXXX
    
    Input examples:
    - "9812345678" -> "+9779812345678"
    - "98 123 456 78" -> "+9779812345678"
    - "+977 9812345678" -> "+9779812345678"
    - "977-981-234-5678" -> "+9779812345678"
    
    Args:
        phone: Raw phone number string from user
        
    Returns:
        Cleaned phone number in format +977XXXXXXXXXX
        
    Raises:
        HTTPException: If phone number is invalid
    """
    if not phone:
        raise HTTPException(
            status_code=400,
            detail="Phone number is required"
        )
    
    # Remove all spaces, dashes, parentheses, and other non-digit characters except +
    cleaned = re.sub(r'[^\d+]', '', phone)
    
    # Remove leading + if exists
    if cleaned.startswith('+'):
        cleaned = cleaned[1:]
    
    # Remove leading 977 if exists (we'll add it back)
    if cleaned.startswith('977'):
        cleaned = cleaned[3:]
    
    # Now we should have exactly 10 digits
    if not cleaned.isdigit():
        raise HTTPException(
            status_code=400,
            detail="Phone number must contain only digits"
        )
    
    if len(cleaned) != 10:
        raise HTTPException(
            status_code=400,
            detail="Phone number must be exactly 10 digits"
        )
    
    # Validate Nepal mobile number format (starts with 97 or 98)
    if not cleaned.startswith(('97', '98')):
        raise HTTPException(
            status_code=400,
            detail="Invalid Nepal mobile number. Must start with 97 or 98"
        )
    
    # Return in international format
    return f"+977{cleaned}"


def validate_phone_number(phone: str) -> bool:
    """
    Validate if phone number is in correct format
    
    Args:
        phone: Phone number to validate
        
    Returns:
        True if valid, False otherwise
    """
    try:
        clean_phone_number(phone)
        return True
    except HTTPException:
        return False


# Example usage and tests
if __name__ == "__main__":
    test_cases = [
        "9812345678",
        "98 123 456 78",
        "+977 9812345678",
        "977-981-234-5678",
        "9771234567",  # Invalid - doesn't start with 97/98
        "98123",  # Invalid - too short
    ]
    
    for test in test_cases:
        try:
            result = clean_phone_number(test)
            print(f" {test:20} -> {result}")
        except HTTPException as e:
            print(f" {test:20} -> {e.detail}")