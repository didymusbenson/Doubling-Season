#!/usr/bin/env python3
"""
Script to fetch and process Magic token data from MTGJSON (AllPrintings).
Generates token_database.json for the Doubling Season app.

MTGJSON provides better coverage for newer tokens and includes reverseRelated
card data. This script replaces the Cockatrice XML-based pipeline.

Usage:
    python3 docs/housekeeping/process_tokens_mtgjson.py
    (Run from repo root)
"""

import json
import lzma
import os
import re
import time
from collections import defaultdict
from typing import Dict, List, Set
from urllib.request import urlopen, Request
from email.utils import formatdate, parsedate_to_datetime

MTGJSON_URL = "https://mtgjson.com/api/v5/AllPrintings.json.xz"
CACHE_DIR = os.path.join(os.path.dirname(__file__), "mtgjson_cache")
CACHE_FILE = os.path.join(CACHE_DIR, "AllPrintings.json")
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "token_database.json")

# WUBRG ordering for color sorting (matches Cockatrice script convention)
WUBRG_ORDER = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4}

# Layout types that represent tokens/emblems
TOKEN_LAYOUTS = {'token', 'emblem', 'double_faced_token'}

# Types to exclude (same as Cockatrice script)
EXCLUDED_TYPES = ['Counter', 'State', 'Bounty', 'Dungeon']


def download_with_caching() -> dict:
    """Download AllPrintings.json.xz with HTTP If-Modified-Since caching."""
    os.makedirs(CACHE_DIR, exist_ok=True)

    headers = {
        'User-Agent': 'DoublingSeason-TokenGenerator/1.0',
    }
    if os.path.exists(CACHE_FILE):
        mtime = os.path.getmtime(CACHE_FILE)
        headers['If-Modified-Since'] = formatdate(mtime, usegmt=True)

    req = Request(MTGJSON_URL, headers=headers)
    try:
        print(f"Checking MTGJSON for updates...")
        response = urlopen(req, timeout=120)

        print(f"Downloading AllPrintings.json.xz (~70MB)...")
        compressed = response.read()
        print(f"Downloaded {len(compressed) / 1024 / 1024:.1f}MB, decompressing...")

        raw = lzma.decompress(compressed)
        with open(CACHE_FILE, 'wb') as f:
            f.write(raw)

        print(f"Cached decompressed JSON ({len(raw) / 1024 / 1024:.1f}MB)")
        data = json.loads(raw)

    except Exception as e:
        if hasattr(e, 'code') and e.code == 304:
            print("MTGJSON data is up to date (304 Not Modified), using cache")
            with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
        elif os.path.exists(CACHE_FILE):
            print(f"Download failed ({e}), falling back to cached file")
            with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
        else:
            raise RuntimeError(f"Download failed and no cache available: {e}")

    return data


def sort_colors(colors: List[str]) -> str:
    """Sort colors in WUBRG order and join into a string."""
    sorted_colors = sorted(colors, key=lambda c: WUBRG_ORDER.get(c, 99))
    return ''.join(sorted_colors)


def strip_reminder_text(text: str) -> str:
    """Remove reminder text in parentheses from abilities text."""
    if not text:
        return ''
    cleaned = re.sub(r'\([^)]*\)', '', text)
    cleaned = ' '.join(cleaned.split())
    return cleaned.strip()


def build_scryfall_url(scryfall_id: str) -> str:
    """Build Scryfall CDN image URL from scryfallId."""
    if not scryfall_id:
        return ''
    front = scryfall_id[:2]
    return f"https://cards.scryfall.io/large/front/{front[0]}/{front[1]}/{scryfall_id}.jpg"


def extract_tokens(all_printings: dict) -> List[Dict]:
    """Extract token entries from all sets in AllPrintings data."""
    print("Extracting tokens from all sets...")

    raw_tokens = []
    sets_data = all_printings.get('data', all_printings)

    for set_code, set_data in sets_data.items():
        tokens_list = set_data.get('tokens', [])
        for card in tokens_list:
            layout = card.get('layout', '')
            type_line = card.get('type', '') or card.get('types', '')

            # Filter: must be token/emblem layout AND type must contain Token or Emblem
            if layout not in TOKEN_LAYOUTS:
                continue

            # Build type string from type line
            if isinstance(type_line, list):
                type_line = ' '.join(type_line)

            type_text = card.get('type', '') or ''

            if 'Token' not in type_text and 'Emblem' not in type_text:
                continue

            # Extract fields
            name = card.get('name', '').strip()
            if not name:
                continue

            power = card.get('power', '')
            toughness = card.get('toughness', '')
            pt = f"{power}/{toughness}" if power and toughness else ''

            colors = sort_colors(card.get('colors', []))
            abilities = card.get('text', '') or ''

            # Build artwork entry
            scryfall_id = card.get('identifiers', {}).get('scryfallId', '')
            artwork_url = build_scryfall_url(scryfall_id) if scryfall_id else ''

            # Get reverse related cards (nested under relatedCards)
            related_cards = card.get('relatedCards', {}) or {}
            reverse_related = related_cards.get('reverseRelated', []) or []

            raw_tokens.append({
                'name': name,
                'type': type_text,
                'abilities': abilities,
                'pt': pt,
                'colors': colors,
                'reverse_related': reverse_related,
                'artwork': [{'set': set_code, 'url': artwork_url}] if artwork_url else [],
            })

    print(f"Found {len(raw_tokens)} raw token entries across all sets")
    return raw_tokens


def clean_and_dedup(tokens: List[Dict]) -> List[Dict]:
    """Clean, normalize, and deduplicate tokens. Matches Cockatrice script contract."""
    print("Cleaning and deduplicating tokens...")

    token_groups = defaultdict(lambda: {'token': None, 'reverse_related': set(), 'artwork': {}})

    for token in tokens:
        # Clean name — strip " Token" suffix
        name = re.sub(r'\s*Token\s*$', '', token['name'], flags=re.IGNORECASE).strip()
        if not name:
            continue

        # Clean type — strip "Token " prefix
        type_text = re.sub(r'^Token\s+', '', token['type'], flags=re.IGNORECASE).strip()

        # Clean abilities — strip reminder text
        abilities = strip_reminder_text(token['abilities'])

        # Composite dedup key (must match Cockatrice script and Dart TokenDefinition.id)
        unique_key = f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"

        # Store normalized token
        token_groups[unique_key]['token'] = {
            'name': name,
            'abilities': abilities,
            'pt': token['pt'],
            'colors': token['colors'],
            'type': type_text,
        }

        # Union reverse_related across printings
        for card_name in token['reverse_related']:
            if card_name:
                token_groups[unique_key]['reverse_related'].add(card_name)

        # Collect artwork (dedup by URL)
        for art in token.get('artwork', []):
            url = art.get('url', '')
            if url and url not in token_groups[unique_key]['artwork']:
                token_groups[unique_key]['artwork'][url] = art['set']

    # Build final list
    cleaned = []
    excluded_count = 0
    for unique_key, data in token_groups.items():
        if data['token'] is None:
            continue

        type_text = data['token']['type']
        if any(exc in type_text for exc in EXCLUDED_TYPES):
            excluded_count += 1
            continue

        popularity = len(data['reverse_related'])
        artwork_array = [
            {'set': set_code, 'url': url}
            for url, set_code in data['artwork'].items()
        ]
        reverse_related_list = sorted(data['reverse_related'])

        entry = data['token'].copy()
        entry['popularity'] = popularity
        entry['artwork'] = artwork_array
        entry['reverse_related'] = reverse_related_list
        cleaned.append(entry)

    if excluded_count > 0:
        print(f"Excluded {excluded_count} non-traditional token types (Counter/State/Bounty/Dungeon)")

    cleaned.sort(key=lambda x: x['name'])
    print(f"Processed {len(cleaned)} unique tokens after deduplication")
    return cleaned


def load_custom_tokens(custom_file: str = None) -> List[Dict]:
    """Load custom tokens from JSON file."""
    if custom_file is None:
        custom_file = os.path.join(os.path.dirname(__file__), 'custom_tokens.json')

    if not os.path.exists(custom_file):
        print(f"No custom tokens file found at {custom_file}")
        return []

    try:
        with open(custom_file, 'r', encoding='utf-8') as f:
            custom_tokens = json.load(f)

        if not custom_tokens or not isinstance(custom_tokens, list):
            print("Custom tokens file is empty or not a JSON array")
            return []

        print(f"Loaded {len(custom_tokens)} custom tokens")
        return custom_tokens
    except Exception as e:
        print(f"Error loading custom tokens: {e}")
        return []


def merge_custom_tokens(generated: List[Dict], custom: List[Dict]) -> List[Dict]:
    """Merge custom tokens with generated tokens (custom overrides on dedup)."""
    if not custom:
        return generated

    print(f"Merging {len(custom)} custom tokens with {len(generated)} generated tokens")
    for token in custom:
        token.setdefault('reverse_related', [])
        token.setdefault('artwork', [])

    merged = generated + custom
    print(f"Merged list: {len(merged)} total (before dedup)")
    return merged


def analyze_popularity(tokens: List[Dict]):
    """Print popularity distribution analysis."""
    print("\n=== Popularity Distribution Analysis ===")
    popularities = sorted([t['popularity'] for t in tokens], reverse=True)

    if not popularities:
        print("No tokens to analyze")
        return

    print(f"Total tokens: {len(tokens)}")
    print(f"Min popularity: {min(popularities)}")
    print(f"Max popularity: {max(popularities)}")
    print(f"Mean popularity: {sum(popularities) / len(popularities):.2f}")
    print(f"Median popularity: {popularities[len(popularities) // 2]}")

    print("\nTop 20 most popular tokens:")
    top = sorted(tokens, key=lambda x: (-x['popularity'], x['name']))[:20]
    for i, t in enumerate(top, 1):
        colors = t['colors'] if t['colors'] else 'Colorless'
        print(f"  {i:2d}. {t['name']:30s} {t['pt']:8s} [{colors:5s}] - Pop: {t['popularity']}")


def save_output(tokens: List[Dict], output_path: str):
    """Save tokens to JSON file."""
    # Normalize output path
    output_path = os.path.normpath(output_path)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    print(f"\nSaving {len(tokens)} tokens to {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(tokens, f, indent=2, ensure_ascii=False)
    print(f"Done! Saved {len(tokens)} tokens.")


def main():
    """Main execution."""
    start = time.time()

    # Download / use cached MTGJSON data
    all_printings = download_with_caching()

    # Extract tokens from all sets
    raw_tokens = extract_tokens(all_printings)

    # Load and merge custom tokens
    custom_tokens = load_custom_tokens()
    merged = merge_custom_tokens(raw_tokens, custom_tokens)

    # Clean, normalize, deduplicate
    cleaned = clean_and_dedup(merged)

    # Analyze popularity
    analyze_popularity(cleaned)

    # Save output
    save_output(cleaned, OUTPUT_PATH)

    # Summary
    color_counts = defaultdict(int)
    for t in cleaned:
        color_counts[t['colors'] if t['colors'] else 'Colorless'] += 1

    print("\n=== Token Database Summary ===")
    print(f"Total tokens: {len(cleaned)}")
    print("\nTokens by color:")
    for color, count in sorted(color_counts.items()):
        print(f"  {color}: {count}")

    elapsed = time.time() - start
    print(f"\nCompleted in {elapsed:.1f}s")


if __name__ == "__main__":
    main()
