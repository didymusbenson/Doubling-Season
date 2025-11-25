#!/usr/bin/env python3
"""
Script to fetch and process Magic token data from GitHub with popularity metrics.
Generates TokenDatabase.json for the Doubling Season iOS app.
"""

import json
import re
import xml.etree.ElementTree as ET
from urllib.request import urlopen
from typing import Dict, List, Optional, Set
from collections import defaultdict
import os

def fetch_xml_data(url: str) -> str:
    """Fetch XML data from the given URL."""
    print(f"Fetching XML data from: {url}")
    with urlopen(url) as response:
        return response.read().decode('utf-8')

def parse_token_xml(xml_content: str) -> List[Dict]:
    """Parse XML content and extract token information including reverse-related cards."""
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

        # Extract reverse-related cards (NEW)
        reverse_related = []
        for reverse_elem in card.findall('reverse-related'):
            if reverse_elem.text:
                reverse_related.append(reverse_elem.text.strip())

        # Extract artwork URLs from <set> tags
        artwork = []
        for set_elem in card.findall('set'):
            pic_url = set_elem.get('picURL')
            set_code = set_elem.text
            if pic_url and set_code:
                artwork.append({
                    'set': set_code.strip(),
                    'url': pic_url.strip()
                })

        # Create token data
        token_data = {
            'name': name_text,
            'type': type_text if type_text else "Token",
            'abilities': abilities_text,
            'pt': pt_text,
            'colors': colors_text,
            'reverse_related': reverse_related,  # Track reverse-related cards
            'artwork': artwork  # Track artwork URLs from sets
        }

        tokens.append(token_data)

    return tokens

def clean_token_data(tokens: List[Dict]) -> List[Dict]:
    """Clean and normalize token data, calculating popularity from unique reverse-related cards."""
    print("Cleaning and normalizing token data with popularity calculation...")

    # First pass: group by deduplication key and collect unique reverse-related cards and artwork
    token_groups = defaultdict(lambda: {'token': None, 'reverse_related': set(), 'artwork': {}})

    for token in tokens:
        # Clean name - remove "Token" suffix and extra whitespace
        name = token['name']
        name = re.sub(r'\s*Token\s*$', '', name, flags=re.IGNORECASE)
        name = name.strip()

        # Skip if empty name
        if not name:
            continue

        # Clean type - remove "Token" prefix since it's not a real Magic type
        type_text = token['type']
        # Remove "Token " prefix (case-insensitive, handles "Token Creature", "Token Artifact", etc.)
        type_text = re.sub(r'^Token\s+', '', type_text, flags=re.IGNORECASE)
        type_text = type_text.strip()

        # Clean abilities text
        abilities = token['abilities']
        if abilities:
            # Remove reminder text in parentheses
            abilities = re.sub(r'\([^)]*\)', '', abilities)
            # Clean up whitespace and newlines
            abilities = ' '.join(abilities.split())
            abilities = abilities.strip()

        # Create unique identifier for deduplication
        unique_key = f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"

        # Store token data (will be overwritten if duplicate, which is fine)
        token_groups[unique_key]['token'] = {
            'name': name,
            'abilities': abilities,
            'pt': token['pt'],
            'colors': token['colors'] if token['colors'] else "",
            'type': type_text
        }

        # Add reverse-related cards to the set (automatically handles uniqueness)
        for card_name in token['reverse_related']:
            token_groups[unique_key]['reverse_related'].add(card_name)

        # Add artwork URLs (use dict to deduplicate by URL, store set code as value)
        for art in token.get('artwork', []):
            if art['url'] not in token_groups[unique_key]['artwork']:
                token_groups[unique_key]['artwork'][art['url']] = art['set']

    # Second pass: create final token list with popularity
    cleaned_tokens = []
    excluded_count = 0
    for unique_key, data in token_groups.items():
        if data['token'] is None:
            continue

        # Exclude non-traditional token types (Counter, State, Bounty, Dungeon)
        # These are game state markers, not actual creature/artifact tokens
        type_text = data['token']['type']
        excluded_types = ['Counter', 'State', 'Bounty', 'Dungeon']
        if any(excluded in type_text for excluded in excluded_types):
            excluded_count += 1
            continue  # Skip this token

        # Popularity = count of unique reverse-related cards
        popularity = len(data['reverse_related'])

        # Convert artwork dict back to array of objects
        artwork_array = [
            {'set': set_code, 'url': url}
            for url, set_code in data['artwork'].items()
        ]

        token_entry = data['token'].copy()
        token_entry['popularity'] = popularity
        token_entry['artwork'] = artwork_array
        cleaned_tokens.append(token_entry)

    if excluded_count > 0:
        print(f"Excluded {excluded_count} non-traditional token types (Counter/State/Bounty/Dungeon)")

    # Sort tokens by name for consistency
    cleaned_tokens.sort(key=lambda x: x['name'])

    return cleaned_tokens

def analyze_popularity_distribution(tokens: List[Dict]) -> Dict:
    """Analyze the distribution of popularity scores."""
    print("\n=== Popularity Distribution Analysis ===")

    popularities = [token['popularity'] for token in tokens]
    popularities.sort(reverse=True)

    stats = {
        'total_tokens': len(tokens),
        'min': min(popularities) if popularities else 0,
        'max': max(popularities) if popularities else 0,
        'mean': sum(popularities) / len(popularities) if popularities else 0,
        'median': popularities[len(popularities) // 2] if popularities else 0
    }

    # Calculate percentiles
    def percentile(data, p):
        if not data:
            return 0
        k = (len(data) - 1) * (p / 100)
        f = int(k)
        c = int(k) + 1 if k < len(data) - 1 else int(k)
        if f == c:
            return data[f]
        return data[f] * (c - k) + data[c] * (k - f)

    stats['p10'] = percentile(popularities, 10)
    stats['p25'] = percentile(popularities, 25)
    stats['p50'] = percentile(popularities, 50)
    stats['p75'] = percentile(popularities, 75)
    stats['p90'] = percentile(popularities, 90)
    stats['p95'] = percentile(popularities, 95)
    stats['p99'] = percentile(popularities, 99)

    print(f"Total tokens: {stats['total_tokens']}")
    print(f"Min popularity: {stats['min']}")
    print(f"Max popularity: {stats['max']}")
    print(f"Mean popularity: {stats['mean']:.2f}")
    print(f"Median popularity: {stats['median']}")
    print("\nPercentiles:")
    print(f"  10th: {stats['p10']}")
    print(f"  25th: {stats['p25']}")
    print(f"  50th (median): {stats['p50']}")
    print(f"  75th: {stats['p75']}")
    print(f"  90th: {stats['p90']}")
    print(f"  95th: {stats['p95']}")
    print(f"  99th: {stats['p99']}")

    # Count distribution
    popularity_counts = {}
    for pop in popularities:
        popularity_counts[pop] = popularity_counts.get(pop, 0) + 1

    print("\nTop 20 most popular tokens:")
    top_tokens = sorted(tokens, key=lambda x: (-x['popularity'], x['name']))[:20]
    for i, token in enumerate(top_tokens, 1):
        colors = token['colors'] if token['colors'] else 'Colorless'
        print(f"  {i:2d}. {token['name']:30s} {token['pt']:8s} [{colors:5s}] - Popularity: {token['popularity']}")

    print("\nPopularity frequency distribution:")
    print("Popularity | Count | Cumulative")
    print("-" * 40)
    cumulative = 0
    for pop in sorted(popularity_counts.keys(), reverse=True)[:30]:
        count = popularity_counts[pop]
        cumulative += count
        print(f"{pop:10d} | {count:5d} | {cumulative:10d}")

    # Suggest bracket boundaries
    print("\n=== Suggested Bracket Boundaries ===")
    print("Goal: Create 6 brackets with roughly 50 tokens each\n")

    # Find top 50 threshold
    if len(popularities) >= 50:
        bracket1_threshold = popularities[49]
        print(f"Bracket 1 (Top 50): popularity >= {bracket1_threshold}")

        # Distribute remaining tokens into 5 brackets
        remaining = popularities[50:]
        if remaining:
            chunk_size = len(remaining) // 5
            bracket2_threshold = remaining[min(chunk_size, len(remaining)-1)]
            bracket3_threshold = remaining[min(chunk_size*2, len(remaining)-1)]
            bracket4_threshold = remaining[min(chunk_size*3, len(remaining)-1)]
            bracket5_threshold = remaining[min(chunk_size*4, len(remaining)-1)]

            print(f"Bracket 2: popularity >= {bracket2_threshold} (and < {bracket1_threshold})")
            print(f"Bracket 3: popularity >= {bracket3_threshold} (and < {bracket2_threshold})")
            print(f"Bracket 4: popularity >= {bracket4_threshold} (and < {bracket3_threshold})")
            print(f"Bracket 5: popularity >= {bracket5_threshold} (and < {bracket4_threshold})")
            print(f"Bracket 6: popularity < {bracket5_threshold}")

            # Count tokens per bracket
            print("\nTokens per bracket:")
            print(f"  Bracket 1: {sum(1 for p in popularities if p >= bracket1_threshold)} tokens")
            print(f"  Bracket 2: {sum(1 for p in popularities if bracket2_threshold <= p < bracket1_threshold)} tokens")
            print(f"  Bracket 3: {sum(1 for p in popularities if bracket3_threshold <= p < bracket2_threshold)} tokens")
            print(f"  Bracket 4: {sum(1 for p in popularities if bracket4_threshold <= p < bracket3_threshold)} tokens")
            print(f"  Bracket 5: {sum(1 for p in popularities if bracket5_threshold <= p < bracket4_threshold)} tokens")
            print(f"  Bracket 6: {sum(1 for p in popularities if p < bracket5_threshold)} tokens")

    return stats

def load_custom_tokens(custom_file: str = 'custom_tokens.json') -> List[Dict]:
    """Load custom tokens from JSON file. Gracefully handles missing or empty files."""
    if not os.path.exists(custom_file):
        print(f"No custom tokens file found at {custom_file}")
        return []

    try:
        with open(custom_file, 'r', encoding='utf-8') as f:
            custom_tokens = json.load(f)

        # Handle empty array gracefully
        if not custom_tokens:
            print(f"Custom tokens file is empty (no tokens to merge)")
            return []

        # Validate that it's a list
        if not isinstance(custom_tokens, list):
            print(f"Warning: Custom tokens file is not a JSON array, skipping")
            return []

        print(f"Loaded {len(custom_tokens)} custom tokens")
        return custom_tokens
    except json.JSONDecodeError as e:
        print(f"Error parsing custom tokens JSON: {e}")
        return []
    except Exception as e:
        print(f"Error loading custom tokens: {e}")
        return []

def merge_custom_tokens(generated_tokens: List[Dict], custom_tokens: List[Dict]) -> List[Dict]:
    """
    Merge custom tokens with generated tokens.
    Custom tokens are appended after generated tokens, so during deduplication
    they will override generated tokens with matching composite IDs (last-write-wins).
    """
    if not custom_tokens:
        return generated_tokens

    print(f"Merging {len(custom_tokens)} custom tokens with {len(generated_tokens)} generated tokens")

    # Convert custom tokens to match the format of generated tokens
    # Custom tokens don't have reverse_related or artwork, so we add empty defaults
    for token in custom_tokens:
        if 'reverse_related' not in token:
            token['reverse_related'] = []
        if 'artwork' not in token:
            token['artwork'] = []

    # Append custom tokens after generated tokens (ensures they override during dedup)
    merged = generated_tokens + custom_tokens
    print(f"Merged list contains {len(merged)} total tokens (before deduplication)")

    return merged

def save_json_database(tokens: List[Dict], output_path: str):
    """Save tokens to JSON file."""
    print(f"\nSaving {len(tokens)} tokens to {output_path}")

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(tokens, f, indent=2, ensure_ascii=False)

    print(f"Successfully saved TokenDatabase.json with {len(tokens)} tokens")

def main():
    """Main execution function."""
    # URL for the Magic Token XML data
    xml_url = "https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml"

    # Output path for the JSON database
    output_path = "../../assets/token_database.json"

    try:
        # Fetch XML data
        xml_content = fetch_xml_data(xml_url)

        # Parse tokens from XML
        raw_tokens = parse_token_xml(xml_content)
        print(f"Found {len(raw_tokens)} raw token entries")

        # Load custom tokens
        custom_tokens = load_custom_tokens('custom_tokens.json')

        # Merge custom tokens with generated tokens (before cleaning)
        merged_tokens = merge_custom_tokens(raw_tokens, custom_tokens)

        # Clean and normalize the data (this includes deduplication)
        cleaned_tokens = clean_token_data(merged_tokens)
        print(f"Processed {len(cleaned_tokens)} unique tokens after cleaning and deduplication")

        # Analyze popularity distribution
        stats = analyze_popularity_distribution(cleaned_tokens)

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
            print(f"  - {token['name']} ({token['pt']}) - {token['type']} [Popularity: {token['popularity']}]")
            if token['abilities']:
                print(f"    Abilities: {token['abilities'][:50]}...")

    except Exception as e:
        print(f"Error processing tokens: {e}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == "__main__":
    main()
