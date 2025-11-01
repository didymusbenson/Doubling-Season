# XML Token Fetching - Testing Guide

## Quick Test Script

This simple Python script validates that the XML fetching from GitHub works correctly:

```python
#!/usr/bin/env python3
"""
test_xml_fetch.py
Quick test to validate XML fetching from GitHub
"""

import urllib.request
import xml.etree.ElementTree as ET
import sys

def test_xml_fetch():
    """Test fetching and basic parsing of tokens.xml"""
    
    url = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"
    
    print(f"Testing XML fetch from: {url}")
    print("-" * 50)
    
    try:
        # Fetch XML
        print("1. Fetching XML from GitHub...")
        with urllib.request.urlopen(url) as response:
            xml_content = response.read()
        print(f"   ✅ Successfully fetched {len(xml_content)} bytes")
        
        # Parse XML
        print("\n2. Parsing XML structure...")
        root = ET.fromstring(xml_content)
        print(f"   ✅ XML parsed successfully")
        print(f"   Root tag: {root.tag}")
        
        # Find cards
        print("\n3. Analyzing card entries...")
        cards = root.findall('.//card')
        print(f"   ✅ Found {len(cards)} card entries")
        
        # Sample some tokens
        print("\n4. Sampling token data...")
        token_count = 0
        sample_tokens = []
        
        for card in cards[:100]:  # Check first 100 cards
            name = card.findtext('.//name', '')
            card_type = card.findtext('.//type', '')
            
            # Check if it's a token
            if 'Token' in card_type or 'Token' in name:
                token_count += 1
                if len(sample_tokens) < 5:
                    pt = card.findtext('.//pt', '')
                    sample_tokens.append({
                        'name': name.replace(' Token', ''),
                        'type': card_type,
                        'pt': pt
                    })
        
        print(f"   ✅ Found {token_count} tokens in first 100 cards")
        
        # Display samples
        print("\n5. Sample tokens found:")
        for token in sample_tokens:
            pt_str = f" ({token['pt']})" if token['pt'] else ""
            print(f"   - {token['name']}{pt_str}")
            print(f"     Type: {token['type']}")
        
        print("\n" + "=" * 50)
        print("✅ ALL TESTS PASSED!")
        print("The XML fetch and parse functionality is working correctly.")
        
        return True
        
    except urllib.error.URLError as e:
        print(f"❌ Network error: {e}")
        return False
    except ET.ParseError as e:
        print(f"❌ XML parsing error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == '__main__':
    success = test_xml_fetch()
    sys.exit(0 if success else 1)
```

## Running the Test

```bash
# Make executable
chmod +x test_xml_fetch.py

# Run the test
python3 test_xml_fetch.py
```

## Expected Output

```
Testing XML fetch from: https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml
--------------------------------------------------
1. Fetching XML from GitHub...
   ✅ Successfully fetched 1234567 bytes

2. Parsing XML structure...
   ✅ XML parsed successfully
   Root tag: cockatrice_carddatabase

3. Analyzing card entries...
   ✅ Found 5000+ card entries

4. Sampling token data...
   ✅ Found 45 tokens in first 100 cards

5. Sample tokens found:
   - Soldier (1/1)
     Type: Token Creature — Soldier
   - Zombie (2/2)
     Type: Token Creature — Zombie
   - Treasure
     Type: Token Artifact — Treasure
   - Beast (3/3)
     Type: Token Creature — Beast
   - Spirit (1/1)
     Type: Token Creature — Spirit

==================================================
✅ ALL TESTS PASSED!
The XML fetch and parse functionality is working correctly.
```

## XML Structure Documentation

The tokens.xml file from the Cockatrice/Magic-Token repository follows this structure:

### Root Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<cockatrice_carddatabase version="4">
    <sets>
        <!-- Set definitions -->
    </sets>
    <cards>
        <!-- Card/token definitions -->
    </cards>
</cockatrice_carddatabase>
```

### Card/Token Structure
```xml
<card>
    <name>Soldier Token</name>
    <text>Vigilance</text>
    <prop>
        <layout>normal</layout>
        <side>front</side>
        <type>Token Creature — Soldier</type>
        <maintype>Creature</maintype>
        <manacost></manacost>
        <cmc>0</cmc>
        <colors>W</colors>
        <coloridentity>W</coloridentity>
        <pt>1/1</pt>
    </prop>
    <set uuid="1234-5678">
        <name>Token Set</name>
        <longname>Token Set Name</longname>
        <settype>Token</settype>
        <releasedate>2023-01-01</releasedate>
    </set>
    <related></related>
    <reverse-related></reverse-related>
    <token>1</token>
</card>
```

### Key Fields for Token Processing

| XML Path | Description | Example |
|----------|-------------|---------|
| `name` | Token name | "Soldier Token" |
| `text` | Abilities text | "Vigilance" |
| `prop/type` | Full type line | "Token Creature — Soldier" |
| `prop/pt` | Power/Toughness | "1/1" |
| `prop/colors` | Mana colors | "W" or "WU" |
| `prop/manacost` | Mana cost (usually empty for tokens) | "" |
| `token` | Token indicator | "1" |

### Identifying Tokens

Tokens can be identified by:
1. **Type contains "Token"**: `prop/type` includes the word "Token"
2. **Name contains "Token"**: Card name ends with "Token"
3. **Token flag**: `<token>1</token>` element present
4. **Zero CMC creatures**: Creatures with CMC of 0 (additional heuristic)

### Color Mapping

The XML uses single letters for colors:
- `W` = White
- `U` = Blue
- `B` = Black
- `R` = Red
- `G` = Green
- Multiple colors: `WU`, `BR`, etc.
- Colorless: Empty string

## Troubleshooting

### Common Issues and Solutions

1. **Network Error**
   - Check internet connection
   - Verify GitHub is accessible
   - Try using a different network

2. **XML Parse Error**
   - The XML might have been updated with a new structure
   - Check for malformed XML in the source

3. **No Tokens Found**
   - The XML structure might have changed
   - Check the token identification logic

4. **SSL Certificate Error**
   ```python
   # If you encounter SSL issues, you can bypass (not recommended for production):
   import ssl
   ssl._create_default_https_context = ssl._create_unverified_context
   ```

## Integration Testing

After validating the XML fetch works, test the full processing pipeline:

```bash
# Test the complete processing script
python3 process_tokens_xml.py

# Verify output
ls -la TokenDatabase.json

# Check JSON validity
python3 -m json.tool TokenDatabase.json > /dev/null && echo "✅ Valid JSON"

# Count tokens
python3 -c "import json; print(f'Token count: {len(json.load(open(\"TokenDatabase.json\")))}')"
```

## Continuous Validation

For ongoing development, consider:

1. **Scheduled Tests**: Run the test script daily to catch any changes
2. **Version Tracking**: Monitor the XML version attribute
3. **Change Detection**: Compare token counts between updates
4. **Backup Strategy**: Keep previous versions of TokenDatabase.json

## Next Steps

Once testing is successful:
1. Run the full processing script
2. Integrate TokenDatabase.json into the iOS app
3. Test token search functionality
4. Deploy to users

This testing guide ensures the XML fetching and parsing works correctly before full implementation.