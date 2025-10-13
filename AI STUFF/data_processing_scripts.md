# Token Data Processing Scripts

## Python Processing Script

This script processes the raw JSON data and outputs a clean, app-ready token database.

```python
#!/usr/bin/env python3
"""
process_tokens.py
Processes raw Magic token JSON data into a clean format for the iOS app
"""

import json
import re
import sys
from typing import Dict, List, Optional

def clean_text(text: str) -> str:
    """Remove unnecessary formatting and clean up text"""
    if not text:
        return ""
    # Remove reminder text in parentheses if needed
    # text = re.sub(r'\([^)]*\)', '', text)
    # Clean up whitespace
    text = ' '.join(text.split())
    return text.strip()

def extract_colors(colors_str: str) -> str:
    """Normalize color string to WUBRG format"""
    if not colors_str:
        return ""
    
    # Ensure uppercase and only valid colors
    valid_colors = set('WUBRG')
    cleaned = ''.join(c.upper() for c in colors_str if c.upper() in valid_colors)
    
    # Sort in WUBRG order
    color_order = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4}
    return ''.join(sorted(cleaned, key=lambda x: color_order.get(x, 5)))

def is_token(card: Dict) -> bool:
    """Determine if a card is actually a token"""
    name = card.get('name', '').lower()
    card_type = card.get('prop', {}).get('type', '').lower()
    
    # Check for token indicators
    if 'token' in card_type:
        return True
    if '(token)' in name:
        return True
    if 'emblem' in card_type:
        return False  # Emblems aren't tokens
    
    # Additional heuristics
    if card.get('prop', {}).get('cmc') == '0' and 'creature' in card_type:
        # Likely a token if 0 CMC creature
        return True
    
    return False

def process_card(card: Dict) -> Optional[Dict]:
    """Process a single card into token format"""
    if not is_token(card):
        return None
    
    name = card.get('name', '')
    # Remove "(Token)" suffix if present
    name = re.sub(r'\s*\(Token\)\s*$', '', name)
    
    # Extract properties
    prop = card.get('prop', {})
    
    processed = {
        'name': name,
        'abilities': clean_text(card.get('text', '')),
        'pt': prop.get('pt', ''),
        'colors': extract_colors(prop.get('colors', '')),
        'type': prop.get('type', '')
    }
    
    # Only include if it has a valid name
    if processed['name']:
        return processed
    
    return None

def deduplicate_tokens(tokens: List[Dict]) -> List[Dict]:
    """Remove duplicate tokens, keeping the most complete version"""
    seen = {}
    
    for token in tokens:
        name = token['name']
        if name not in seen:
            seen[name] = token
        else:
            # Keep the version with more information
            existing = seen[name]
            if len(token['abilities']) > len(existing['abilities']):
                seen[name] = token
    
    return list(seen.values())

def main():
    if len(sys.argv) != 2:
        print("Usage: python process_tokens.py <input_json_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading input file: {e}")
        sys.exit(1)
    
    # Extract cards array
    cards = data.get('card', [])
    if not cards:
        print("No cards found in JSON")
        sys.exit(1)
    
    # Process each card
    processed_tokens = []
    for card in cards:
        processed = process_card(card)
        if processed:
            processed_tokens.append(processed)
    
    # Remove duplicates
    processed_tokens = deduplicate_tokens(processed_tokens)
    
    # Sort by name for consistency
    processed_tokens.sort(key=lambda x: x['name'])
    
    # Output statistics
    print(f"Processed {len(cards)} cards")
    print(f"Found {len(processed_tokens)} unique tokens")
    
    # Write output
    output_file = 'TokenDatabase.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(processed_tokens, f, indent=2, ensure_ascii=False)
    
    print(f"Token database written to {output_file}")
    
    # Show sample output
    if processed_tokens:
        print("\nSample tokens:")
        for token in processed_tokens[:3]:
            print(f"  - {token['name']} ({token['pt']}) - {token['colors'] or 'Colorless'}")

if __name__ == '__main__':
    main()
```

## Swift Processing Script (Alternative)

For developers who prefer to stay in the Swift ecosystem:

```swift
#!/usr/bin/swift
// process_tokens.swift
// Run with: swift process_tokens.swift input.json

import Foundation

// MARK: - Models

struct SourceData: Codable {
    let card: [SourceCard]
}

struct SourceCard: Codable {
    let name: String?
    let text: String?
    let prop: CardProp?
    let set: SetInfo?
    
    struct CardProp: Codable {
        let type: String?
        let maintype: String?
        let cmc: String?
        let pt: String?
        let colors: String?
    }
    
    struct SetInfo: Codable {
        // We don't need set info for tokens
    }
}

struct ProcessedToken: Codable {
    let name: String
    let abilities: String
    let pt: String
    let colors: String
    let type: String
}

// MARK: - Processing Functions

func cleanText(_ text: String?) -> String {
    guard let text = text else { return "" }
    // Remove extra whitespace
    let cleaned = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    return cleaned
}

func extractColors(_ colors: String?) -> String {
    guard let colors = colors else { return "" }
    
    let validColors = Set("WUBRG")
    let cleaned = colors.uppercased().filter { validColors.contains($0) }
    
    // Sort in WUBRG order
    let colorOrder: [Character: Int] = ["W": 0, "U": 1, "B": 2, "R": 3, "G": 4]
    let sorted = cleaned.sorted { 
        (colorOrder[$0] ?? 5) < (colorOrder[$1] ?? 5) 
    }
    
    return String(sorted)
}

func isToken(_ card: SourceCard) -> Bool {
    let name = (card.name ?? "").lowercased()
    let type = (card.prop?.type ?? "").lowercased()
    
    // Check for token indicators
    if type.contains("token") { return true }
    if name.contains("(token)") { return true }
    if type.contains("emblem") { return false }
    
    // Additional heuristics
    if card.prop?.cmc == "0" && type.contains("creature") {
        return true
    }
    
    return false
}

func processCard(_ card: SourceCard) -> ProcessedToken? {
    guard isToken(card),
          let name = card.name else {
        return nil
    }
    
    // Clean up name (remove "(Token)" suffix)
    let cleanedName = name.replacingOccurrences(of: #"\s*\(Token\)\s*$"#, 
                                                with: "", 
                                                options: .regularExpression)
    
    return ProcessedToken(
        name: cleanedName,
        abilities: cleanText(card.text),
        pt: card.prop?.pt ?? "",
        colors: extractColors(card.prop?.colors),
        type: card.prop?.type ?? ""
    )
}

func deduplicateTokens(_ tokens: [ProcessedToken]) -> [ProcessedToken] {
    var seen: [String: ProcessedToken] = [:]
    
    for token in tokens {
        if let existing = seen[token.name] {
            // Keep the version with more information
            if token.abilities.count > existing.abilities.count {
                seen[token.name] = token
            }
        } else {
            seen[token.name] = token
        }
    }
    
    return Array(seen.values).sorted { $0.name < $1.name }
}

// MARK: - Main

func main() {
    let arguments = CommandLine.arguments
    guard arguments.count == 2 else {
        print("Usage: swift process_tokens.swift <input_json_file>")
        exit(1)
    }
    
    let inputPath = arguments[1]
    let inputURL = URL(fileURLWithPath: inputPath)
    
    do {
        let data = try Data(contentsOf: inputURL)
        let sourceData = try JSONDecoder().decode(SourceData.self, from: data)
        
        print("Processing \(sourceData.card.count) cards...")
        
        // Process cards
        let tokens = sourceData.card.compactMap { processCard($0) }
        let uniqueTokens = deduplicateTokens(tokens)
        
        print("Found \(uniqueTokens.count) unique tokens")
        
        // Write output
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(uniqueTokens)
        
        let outputURL = URL(fileURLWithPath: "TokenDatabase.json")
        try outputData.write(to: outputURL)
        
        print("Token database written to TokenDatabase.json")
        
        // Show samples
        print("\nSample tokens:")
        for token in uniqueTokens.prefix(3) {
            let colors = token.colors.isEmpty ? "Colorless" : token.colors
            print("  - \(token.name) (\(token.pt)) - \(colors)")
        }
        
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

main()
```

## Shell Script for Updates

```bash
#!/bin/bash
# update_tokens.sh
# Automates the token database update process

set -e  # Exit on error

echo "Token Database Update Script"
echo "============================"

# Configuration
SOURCE_URL="https://example.com/api/tokens.json"  # Replace with actual URL
TEMP_FILE="tokens_raw.json"
OUTPUT_FILE="TokenDatabase.json"
PROJECT_PATH="./Doubling Season"

# Step 1: Download latest data
echo "Downloading latest token data..."
curl -L -o "$TEMP_FILE" "$SOURCE_URL" || {
    echo "Failed to download token data"
    exit 1
}

# Step 2: Process the data
echo "Processing tokens..."
python3 process_tokens.py "$TEMP_FILE" || {
    echo "Failed to process tokens"
    exit 1
}

# Step 3: Validate output
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not created"
    exit 1
fi

# Check file size (should be reasonable)
FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "Warning: Output file seems too small ($FILE_SIZE bytes)"
    exit 1
fi

# Step 4: Copy to Xcode project
echo "Copying to Xcode project..."
cp "$OUTPUT_FILE" "$PROJECT_PATH/$OUTPUT_FILE"

# Step 5: Clean up
rm -f "$TEMP_FILE"

echo "✅ Token database updated successfully!"
echo "   File size: $FILE_SIZE bytes"
echo "   Location: $PROJECT_PATH/$OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Open Xcode project"
echo "2. Ensure TokenDatabase.json is added to target"
echo "3. Build and test the app"
```

## Usage Instructions

### Running the Python Script
```bash
# Make executable
chmod +x process_tokens.py

# Run with input file
python3 process_tokens.py source_tokens.json
```

### Running the Swift Script
```bash
# Make executable
chmod +x process_tokens.swift

# Run with input file
swift process_tokens.swift source_tokens.json
```

### Automated Updates
```bash
# Make update script executable
chmod +x update_tokens.sh

# Run update
./update_tokens.sh
```

## Sample Output Format

The processed `TokenDatabase.json` will look like:

```json
[
  {
    "name": "Soldier",
    "abilities": "Vigilance",
    "pt": "1/1",
    "colors": "W",
    "type": "Token Creature — Soldier"
  },
  {
    "name": "Zombie",
    "abilities": "",
    "pt": "2/2",
    "colors": "B",
    "type": "Token Creature — Zombie"
  },
  {
    "name": "Treasure",
    "abilities": "{T}, Sacrifice this artifact: Add one mana of any color.",
    "pt": "",
    "colors": "",
    "type": "Token Artifact — Treasure"
  }
]
```

## Validation Checklist

Before using the processed data:

- [ ] Verify all tokens have names
- [ ] Check color formatting (WUBRG order)
- [ ] Validate P/T format (e.g., "2/2")
- [ ] Ensure abilities text is clean
- [ ] Confirm no duplicate entries
- [ ] Test JSON validity
- [ ] Check file size is reasonable