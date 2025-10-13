# XML Token Data Processing Scripts

## Overview
These scripts fetch and parse token data from the Magic-Token GitHub repository's XML file instead of using JSON. The XML file contains comprehensive token information maintained by the Cockatrice community.

## Data Source
- **URL**: https://github.com/Cockatrice/Magic-Token/blob/master/tokens.xml
- **Raw URL**: https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml
- **Format**: XML with token definitions
- **Maintained by**: Cockatrice community

## Python XML Processing Script

```python
#!/usr/bin/env python3
"""
process_tokens_xml.py
Fetches and processes Magic token XML data from GitHub into a clean format for the iOS app
"""

import xml.etree.ElementTree as ET
import json
import re
import sys
import urllib.request
from typing import Dict, List, Optional

# GitHub raw content URL for tokens.xml
TOKENS_XML_URL = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"

def fetch_xml_data(url: str) -> str:
    """Fetch XML content from GitHub"""
    try:
        with urllib.request.urlopen(url) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        print(f"Error fetching XML from {url}: {e}")
        sys.exit(1)

def clean_text(text: str) -> str:
    """Remove unnecessary formatting and clean up text"""
    if not text:
        return ""
    # Clean up whitespace and newlines
    text = ' '.join(text.split())
    # Remove excessive spaces around punctuation
    text = re.sub(r'\s+([,.])', r'\1', text)
    return text.strip()

def extract_colors_from_xml(card_element) -> str:
    """Extract colors from XML card element"""
    colors = []
    color_map = {
        'white': 'W',
        'blue': 'U', 
        'black': 'B',
        'red': 'R',
        'green': 'G'
    }
    
    # Check for color elements
    for color_name, color_code in color_map.items():
        if card_element.find(f'.//{color_name}') is not None:
            colors.append(color_code)
    
    # Also check manacost for color indicators
    manacost = card_element.findtext('.//manacost', '')
    for char in manacost:
        if char in 'WUBRG':
            if char not in colors:
                colors.append(char)
    
    # Sort in WUBRG order
    color_order = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4}
    return ''.join(sorted(colors, key=lambda x: color_order.get(x, 5)))

def parse_token_from_xml(card_element) -> Optional[Dict]:
    """Parse a single card element from XML into token format"""
    
    # Extract basic properties
    name = card_element.findtext('.//name', '').strip()
    if not name:
        return None
    
    # Get card type
    card_type = card_element.findtext('.//type', '')
    
    # Check if it's actually a token
    if 'Token' not in card_type and not name.endswith('Token'):
        # Additional check for token indicators
        set_element = card_element.find('.//set')
        if set_element is not None:
            # If it has a regular set code, it's probably not a token
            set_code = set_element.text
            if set_code and not set_code.startswith('T'):
                return None
    
    # Extract power/toughness
    pt_element = card_element.find('.//pt')
    pt = pt_element.text if pt_element is not None else ''
    
    # Extract abilities/text
    text_element = card_element.find('.//text')
    abilities = clean_text(text_element.text if text_element is not None else '')
    
    # Extract colors
    colors = extract_colors_from_xml(card_element)
    
    # Clean up name (remove "Token" suffix if present)
    name = re.sub(r'\s*Token\s*$', '', name, flags=re.IGNORECASE)
    
    return {
        'name': name,
        'abilities': abilities,
        'pt': pt,
        'colors': colors,
        'type': card_type
    }

def deduplicate_tokens(tokens: List[Dict]) -> List[Dict]:
    """Remove duplicate tokens, keeping the most complete version"""
    seen = {}
    
    for token in tokens:
        key = f"{token['name']}_{token['pt']}_{token['colors']}"
        
        if key not in seen:
            seen[key] = token
        else:
            # Keep the version with more information
            existing = seen[key]
            if len(token['abilities']) > len(existing['abilities']):
                seen[key] = token
    
    return list(seen.values())

def main():
    print("Fetching token data from GitHub...")
    xml_content = fetch_xml_data(TOKENS_XML_URL)
    
    print("Parsing XML...")
    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}")
        sys.exit(1)
    
    # Find all card elements
    cards = root.findall('.//card')
    print(f"Found {len(cards)} card entries in XML")
    
    # Process each card
    processed_tokens = []
    for card in cards:
        token = parse_token_from_xml(card)
        if token:
            processed_tokens.append(token)
    
    # Remove duplicates
    processed_tokens = deduplicate_tokens(processed_tokens)
    
    # Sort by name for consistency
    processed_tokens.sort(key=lambda x: (x['name'], x['pt'], x['colors']))
    
    print(f"Processed {len(processed_tokens)} unique tokens")
    
    # Write output
    output_file = 'TokenDatabase.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(processed_tokens, f, indent=2, ensure_ascii=False)
    
    print(f"Token database written to {output_file}")
    
    # Show sample output
    if processed_tokens:
        print("\nSample tokens:")
        for token in processed_tokens[:5]:
            colors = token['colors'] or 'Colorless'
            pt = f"({token['pt']})" if token['pt'] else ""
            print(f"  - {token['name']} {pt} - {colors}")
            if token['abilities']:
                print(f"    {token['abilities'][:50]}...")

if __name__ == '__main__':
    main()
```

## Swift XML Processing Script

```swift
#!/usr/bin/swift
// process_tokens_xml.swift
// Fetches and processes Magic token XML data from GitHub

import Foundation

// MARK: - Models

struct ProcessedToken: Codable {
    let name: String
    let abilities: String
    let pt: String
    let colors: String
    let type: String
}

// MARK: - XML Parser Delegate

class TokenXMLParser: NSObject, XMLParserDelegate {
    private var tokens: [ProcessedToken] = []
    private var currentElement = ""
    private var currentToken: [String: String] = [:]
    private var currentText = ""
    private var isInCard = false
    
    func parse(data: Data) -> [ProcessedToken] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return tokens
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, 
                namespaceURI: String?, qualifiedName qName: String?, 
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "card" {
            isInCard = true
            currentToken = [:]
        }
        
        currentText = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, 
                namespaceURI: String?, qualifiedName qName: String?) {
        
        guard isInCard else { return }
        
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "name":
            currentToken["name"] = trimmedText
        case "text":
            currentToken["abilities"] = cleanText(trimmedText)
        case "pt":
            currentToken["pt"] = trimmedText
        case "type":
            currentToken["type"] = trimmedText
        case "manacost":
            // Extract colors from manacost
            let colors = extractColors(from: trimmedText)
            currentToken["colors"] = colors
        case "card":
            // End of card, process if it's a token
            if let token = processCurrentToken() {
                tokens.append(token)
            }
            isInCard = false
            currentToken = [:]
        default:
            // Check for color indicators
            if ["white", "blue", "black", "red", "green"].contains(elementName) {
                var colors = currentToken["colors"] ?? ""
                let colorMap = ["white": "W", "blue": "U", "black": "B", "red": "R", "green": "G"]
                if let color = colorMap[elementName] {
                    if !colors.contains(color) {
                        colors += color
                    }
                }
                currentToken["colors"] = sortColors(colors)
            }
        }
    }
    
    private func cleanText(_ text: String) -> String {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func extractColors(from manacost: String) -> String {
        let validColors = Set("WUBRG")
        let colors = manacost.filter { validColors.contains($0) }
        return sortColors(colors)
    }
    
    private func sortColors(_ colors: String) -> String {
        let colorOrder: [Character: Int] = ["W": 0, "U": 1, "B": 2, "R": 3, "G": 4]
        return String(colors.sorted { (colorOrder[$0] ?? 5) < (colorOrder[$1] ?? 5) })
    }
    
    private func processCurrentToken() -> ProcessedToken? {
        guard let name = currentToken["name"],
              !name.isEmpty else {
            return nil
        }
        
        let type = currentToken["type"] ?? ""
        
        // Check if it's actually a token
        guard type.contains("Token") || name.contains("Token") else {
            return nil
        }
        
        // Clean up name
        let cleanedName = name.replacingOccurrences(of: #"\s*Token\s*$"#, 
                                                    with: "", 
                                                    options: [.regularExpression, .caseInsensitive])
        
        return ProcessedToken(
            name: cleanedName,
            abilities: currentToken["abilities"] ?? "",
            pt: currentToken["pt"] ?? "",
            colors: currentToken["colors"] ?? "",
            type: type
        )
    }
}

// MARK: - Main Functions

func fetchXMLData() -> Data? {
    let urlString = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        return nil
    }
    
    do {
        let data = try Data(contentsOf: url)
        return data
    } catch {
        print("Error fetching XML: \(error)")
        return nil
    }
}

func deduplicateTokens(_ tokens: [ProcessedToken]) -> [ProcessedToken] {
    var seen: [String: ProcessedToken] = [:]
    
    for token in tokens {
        let key = "\(token.name)_\(token.pt)_\(token.colors)"
        
        if let existing = seen[key] {
            // Keep the version with more information
            if token.abilities.count > existing.abilities.count {
                seen[key] = token
            }
        } else {
            seen[key] = token
        }
    }
    
    return Array(seen.values).sorted { 
        if $0.name != $1.name {
            return $0.name < $1.name
        }
        if $0.pt != $1.pt {
            return $0.pt < $1.pt
        }
        return $0.colors < $1.colors
    }
}

// MARK: - Main

func main() {
    print("Fetching token data from GitHub...")
    
    guard let xmlData = fetchXMLData() else {
        print("Failed to fetch XML data")
        exit(1)
    }
    
    print("Parsing XML...")
    let parser = TokenXMLParser()
    let tokens = parser.parse(data: xmlData)
    
    print("Found \(tokens.count) tokens")
    
    // Deduplicate
    let uniqueTokens = deduplicateTokens(tokens)
    print("Reduced to \(uniqueTokens.count) unique tokens")
    
    // Write output
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let outputData = try encoder.encode(uniqueTokens)
        let outputURL = URL(fileURLWithPath: "TokenDatabase.json")
        try outputData.write(to: outputURL)
        
        print("Token database written to TokenDatabase.json")
        
        // Show samples
        print("\nSample tokens:")
        for token in uniqueTokens.prefix(5) {
            let colors = token.colors.isEmpty ? "Colorless" : token.colors
            let pt = token.pt.isEmpty ? "" : "(\(token.pt))"
            print("  - \(token.name) \(pt) - \(colors)")
            if !token.abilities.isEmpty {
                let preview = String(token.abilities.prefix(50))
                print("    \(preview)...")
            }
        }
    } catch {
        print("Error writing output: \(error)")
        exit(1)
    }
}

main()
```

## Updated Shell Script

```bash
#!/bin/bash
# update_tokens_xml.sh
# Fetches and processes token data from GitHub XML

set -e  # Exit on error

echo "Token Database Update Script (XML)"
echo "==================================="

# Configuration
GITHUB_URL="https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"
TEMP_FILE="tokens_temp.xml"
OUTPUT_FILE="TokenDatabase.json"
PROJECT_PATH="./Doubling Season"

# Step 1: Fetch XML from GitHub
echo "Fetching tokens.xml from GitHub..."
curl -L -o "$TEMP_FILE" "$GITHUB_URL" || {
    echo "Failed to download XML from GitHub"
    exit 1
}

# Validate XML was downloaded
if [ ! -f "$TEMP_FILE" ]; then
    echo "Error: XML file not downloaded"
    exit 1
fi

XML_SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE" 2>/dev/null)
echo "Downloaded XML file: $XML_SIZE bytes"

# Step 2: Process the XML data
echo "Processing XML tokens..."
python3 process_tokens_xml.py || {
    echo "Failed to process XML tokens"
    exit 1
}

# Step 3: Validate output
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not created"
    exit 1
fi

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
echo "   Source: GitHub (Cockatrice/Magic-Token)"
echo "   Output size: $FILE_SIZE bytes"
echo "   Location: $PROJECT_PATH/$OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Open Xcode project"
echo "2. Ensure TokenDatabase.json is added to target"
echo "3. Build and test the app"
```

## Direct Fetch Alternative (No Local XML File)

For a simpler approach that doesn't save the XML locally:

```python
#!/usr/bin/env python3
"""
fetch_and_process_tokens.py
Directly fetches and processes token XML from GitHub in one step
"""

import xml.etree.ElementTree as ET
import json
import urllib.request

def main():
    # Fetch directly from GitHub
    url = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"
    
    print(f"Fetching tokens from: {url}")
    with urllib.request.urlopen(url) as response:
        xml_content = response.read()
    
    # Parse XML
    root = ET.fromstring(xml_content)
    
    # Process tokens (rest of the logic from above)
    # ... (processing code here)
    
    print("✅ Tokens processed directly from GitHub")

if __name__ == '__main__':
    main()
```

## Usage Instructions

### One-Step Process
```bash
# Just run the Python script - it fetches and processes in one go
python3 process_tokens_xml.py

# Or use the Swift version
swift process_tokens_xml.swift
```

### Automated Updates
```bash
# Make the update script executable
chmod +x update_tokens_xml.sh

# Run the update
./update_tokens_xml.sh
```

### Manual Testing
```bash
# Test fetching the XML
curl -L "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml" -o test.xml

# Check the structure
head -n 50 test.xml
```

## Benefits of XML Approach

1. **Official Source**: Uses the community-maintained Cockatrice token database
2. **Always Current**: Fetches latest data directly from GitHub
3. **No API Keys**: Public repository, no authentication needed
4. **Comprehensive**: Contains extensive token information
5. **Structured Data**: XML provides clear hierarchical structure
6. **Version Control**: Can track specific commits if needed

## XML Structure Reference

The tokens.xml file has this general structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<cockatrice_carddatabase version="4">
    <cards>
        <card>
            <name>Soldier Token</name>
            <text></text>
            <prop>
                <type>Token Creature — Soldier</type>
                <pt>1/1</pt>
                <colors>W</colors>
            </prop>
        </card>
        <!-- More cards... -->
    </cards>
</cockatrice_carddatabase>
```

## Error Handling

The scripts include error handling for:
- Network failures when fetching from GitHub
- XML parsing errors
- Missing or malformed data
- File system errors
- Invalid token entries

## Validation

After processing, verify:
- [ ] All tokens have valid names
- [ ] Colors are in WUBRG format
- [ ] P/T values are properly formatted
- [ ] Token types are correctly identified
- [ ] No duplicate entries exist
- [ ] JSON output is valid