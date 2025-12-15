def format_item_name(name):
    """
    Format item name to ensure proper capitalization and spacing.
    - Removes extra spaces (no double spaces)
    - Capitalizes first letter of each word
    - Rest of letters are lowercase
    - Strips leading/trailing whitespace
    """
    if not name:
        return ''
    
    # Split by spaces, remove empty strings (handles multiple spaces)
    words = [word.strip() for word in name.split() if word.strip()]
    
    # Capitalize first letter of each word, rest lowercase
    formatted_words = [word.capitalize() for word in words]
    
    # Join with single space
    return ' '.join(formatted_words)

