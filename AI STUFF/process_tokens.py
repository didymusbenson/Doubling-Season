#!/usr/bin/env python3
"""
Script to fetch and process Magic token data from GitHub.
Generates TokenDatabase.json for the Doubling Season iOS app.
"""

import json
import re
import xml.etree.ElementTree as ET
from urllib.request import urlopen
from typing import Dict, List, Optional

def fetch_xml_data(url: str) -> str:
    """Fetch XML data from the given URL."""
    print(f"Fetching XML data from: {url}")
    with urlopen(url) as response:
        return response.read().decode('utf-8')

def parse_token_xml(xml_content: str) -> List[Dict]:
    """Parse XML content and extract token information."""
    print("Parsing XML content...")
    root = ET.fromstring(xml_content)
    
    tokens = []
    # Look for cards within the cards element
    cards_element = root.find('.//cards')
    if cards_element is None:
        print("No cards element found in XML")
        return tokens
    
    for card in cards_element.findall('card'):
        # Check if this is a token (has <token>1</token> element)
        token_elem = card.find('token')
        if token_elem is None or token_elem.text != '1':
            continue
            
        # Extract basic information
        name = card.find('name')
        if name is None or not name.text:
            continue
            
        name_text = name.text.strip()
        
        # Extract type from prop element
        prop = card.find('prop')
        type_text = ""
        pt_text = ""
        colors_text = ""
        
        if prop is not None:
            type_elem = prop.find('type')
            if type_elem is not None and type_elem.text:
                type_text = type_elem.text.strip()
            
            # Extract power/toughness
            pt_elem = prop.find('pt')
            if pt_elem is not None and pt_elem.text:
                pt_text = pt_elem.text.strip()
            
            # Extract colors
            colors_elem = prop.find('colors')
            if colors_elem is not None and colors_elem.text:
                colors_text = colors_elem.text.strip()
        
        # Extract abilities/text
        text_elem = card.find('text')
        abilities_text = ""
        if text_elem is not None and text_elem.text:
            abilities_text = text_elem.text.strip()
        
        # Create token data
        token_data = {
            'name': name_text,
            'type': type_text if type_text else "Token",
            'abilities': abilities_text,
            'pt': pt_text,
            'colors': colors_text
        }
        
        tokens.append(token_data)
    
    return tokens

def clean_token_data(tokens: List[Dict]) -> List[Dict]:
    """Clean and normalize token data."""
    print("Cleaning and normalizing token data...")
    cleaned_tokens = []
    seen_tokens = set()
    
    for token in tokens:
        # Clean name - remove "Token" suffix and extra whitespace
        name = token['name']
        name = re.sub(r'\s*Token\s*$', '', name, flags=re.IGNORECASE)
        name = name.strip()
        
        # Skip if empty name
        if not name:
            continue
        
        # Clean type - ensure it includes "Token" if not already
        type_text = token['type']
        if "Token" not in type_text:
            if "Creature" in type_text:
                type_text = "Token " + type_text
            else:
                type_text = "Token " + type_text
        
        # Clean abilities text
        abilities = token['abilities']
        if abilities:
            # Remove reminder text in parentheses
            abilities = re.sub(r'\([^)]*\)', '', abilities)
            # Clean up whitespace and newlines
            abilities = ' '.join(abilities.split())
            abilities = abilities.strip()
        
        # Create unique identifier for deduplication
        unique_key = f"{name}|{token['pt']}|{token['colors']}|{type_text}"
        
        # Skip duplicates
        if unique_key in seen_tokens:
            continue
        seen_tokens.add(unique_key)
        
        # Create cleaned token entry
        cleaned_token = {
            'name': name,
            'abilities': abilities,
            'pt': token['pt'],
            'colors': token['colors'] if token['colors'] else "",
            'type': type_text
        }
        
        cleaned_tokens.append(cleaned_token)
    
    # Sort tokens by name for consistency
    cleaned_tokens.sort(key=lambda x: x['name'])
    
    return cleaned_tokens

def save_json_database(tokens: List[Dict], output_path: str):
    """Save tokens to JSON file."""
    print(f"Saving {len(tokens)} tokens to {output_path}")
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(tokens, f, indent=2, ensure_ascii=False)
    
    print(f"Successfully saved TokenDatabase.json with {len(tokens)} tokens")

def main():
    """Main execution function."""
    # URL for the Magic Token XML data
    xml_url = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"
    
    # Output path for the JSON database
    output_path = "Doubling Season/TokenDatabase.json"
    
    try:
        # Fetch XML data
        xml_content = fetch_xml_data(xml_url)
        
        # Parse tokens from XML
        raw_tokens = parse_token_xml(xml_content)
        print(f"Found {len(raw_tokens)} raw token entries")
        
        # Clean and normalize the data
        cleaned_tokens = clean_token_data(raw_tokens)
        print(f"Processed {len(cleaned_tokens)} unique tokens after cleaning")
        
        # Save to JSON file
        save_json_database(cleaned_tokens, output_path)
        
        # Print summary statistics
        print("\n=== Token Database Summary ===")
        print(f"Total tokens: {len(cleaned_tokens)}")
        
        # Count tokens by color
        color_counts = {}
        for token in cleaned_tokens:
            colors = token['colors'] if token['colors'] else 'Colorless'
            color_counts[colors] = color_counts.get(colors, 0) + 1
        
        print("\nTokens by color:")
        for color, count in sorted(color_counts.items()):
            print(f"  {color}: {count}")
        
        # Sample tokens
        print("\nSample tokens (first 5):")
        for token in cleaned_tokens[:5]:
            print(f"  - {token['name']} ({token['pt']}) - {token['type']}")
            if token['abilities']:
                print(f"    Abilities: {token['abilities'][:50]}...")
        
    except Exception as e:
        print(f"Error processing tokens: {e}")
        raise

if __name__ == "__main__":
    main()