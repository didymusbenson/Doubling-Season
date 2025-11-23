# Custom Token Maintenance

This document describes how to maintain a curated list of custom tokens that supplement the auto-generated token database from Cockatrice XML data.

## Overview

The token database consists of two sources:
1. **Auto-generated tokens** from `https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml` (800+ tokens)
2. **Custom tokens** manually maintained in `docs/housekeeping/custom_tokens.json`

The `process_tokens_with_popularity.py` script merges both sources and outputs the final database to `assets/token_database.json`.

## Custom Token File Format

**Location:** `docs/housekeeping/custom_tokens.json`

**Format:** JSON array of token objects matching the TokenDefinition structure:

```json
[
  {
    "name": "Custom Dragon",
    "pt": "5/5",
    "colors": "R",
    "abilities": "Flying, haste",
    "type": "Creature"
  },
  {
    "name": "Special Emblem",
    "pt": "",
    "colors": "",
    "abilities": "You get an emblem with 'Creatures you control get +1/+1'",
    "type": "Emblem"
  }
]
```

### Field Descriptions

- **name** (string, required): Token name
- **pt** (string): Power/toughness (e.g., "3/3", "*/4", "1/1"). Empty string for non-creatures
- **colors** (string): Color identity using WUBRG notation (e.g., "W", "UB", "RG"). Empty string for colorless
- **abilities** (string): Token abilities text. Empty string if none
- **type** (string): Token type (e.g., "Creature", "Artifact", "Enchantment", "Emblem")

### Deduplication Key

Custom tokens are deduplicated with auto-generated tokens using the composite ID:
```
name|pt|colors|type|abilities
```

If a custom token has the same composite ID as an auto-generated token, **the custom token takes precedence** (last-write-wins behavior).

## Maintaining Custom Tokens

### Adding a New Custom Token

1. Open `docs/housekeeping/custom_tokens.json`
2. Add a new token object to the JSON array:
   ```json
   {
     "name": "My Custom Token",
     "pt": "2/2",
     "colors": "G",
     "abilities": "Trample",
     "type": "Creature"
   }
   ```
3. Ensure valid JSON syntax (trailing commas, quotes, brackets)
4. Run `python3 docs/housekeeping/process_tokens_with_popularity.py` to regenerate database
5. Verify token appears in `assets/token_database.json`

### Overriding an Auto-Generated Token

To replace an auto-generated token with custom data:

1. Identify the existing token's composite ID (name|pt|colors|type|abilities)
2. Add a custom token with **exact matching fields** for the composite ID
3. Modify any other fields as desired
4. The custom token will replace the auto-generated one during merge

**Example:** Override "Saproling" creature from auto-generated data:
```json
{
  "name": "Saproling",
  "pt": "1/1",
  "colors": "G",
  "abilities": "Custom ability text here",
  "type": "Creature"
}
```

### Removing a Token from Database

Custom tokens cannot "subtract" auto-generated tokens. To exclude an auto-generated token:

1. Add filtering logic to `clean_token_data()` function in the Python script
2. Or add the token to `custom_tokens.json` with a special marker field (requires script modification to filter marked tokens)

**Recommended approach:** Use filtering in the script for exclusions, not custom_tokens.json.

## Script Integration

### Modifying `process_tokens_with_popularity.py`

To enable custom token merging, add this logic to the script:

```python
import json
import os

# After loading and processing XML tokens
def load_custom_tokens():
    """Load custom tokens from JSON file"""
    custom_file = 'docs/housekeeping/custom_tokens.json'

    if not os.path.exists(custom_file):
        print(f"No custom tokens file found at {custom_file}")
        return []

    try:
        with open(custom_file, 'r', encoding='utf-8') as f:
            custom_tokens = json.load(f)
            print(f"Loaded {len(custom_tokens)} custom tokens")
            return custom_tokens
    except Exception as e:
        print(f"Error loading custom tokens: {e}")
        return []

# In main processing flow:
# 1. Load and process XML tokens (existing logic)
generated_tokens = process_xml_tokens()

# 2. Load custom tokens
custom_tokens = load_custom_tokens()

# 3. Merge: Add custom tokens to generated list
all_tokens = generated_tokens + custom_tokens

# 4. Apply deduplication logic (existing logic)
#    Custom tokens will override generated ones with same composite ID
deduplicated_tokens = deduplicate_by_composite_id(all_tokens)

# 5. Output final merged database (existing logic)
output_to_json(deduplicated_tokens)
```

### Merge Behavior

The merge happens **before deduplication**, which means:

1. Generated tokens are loaded first
2. Custom tokens are appended to the list
3. Deduplication runs using composite ID as the key
4. **Last-write-wins:** If a custom token matches a generated token's ID, the custom token survives

This allows custom tokens to:
- Add entirely new tokens not in Cockatrice data
- Override auto-generated tokens with custom data
- Supplement missing tokens or fix incorrect data

## Best Practices

### Version Control

- Commit `custom_tokens.json` to version control
- Track changes over time (see when custom tokens were added/modified)
- Document reasons for custom tokens in commit messages

### Validation

Before regenerating the database:

1. Validate JSON syntax (use a JSON validator)
2. Ensure all required fields are present
3. Check color codes are valid (W, U, B, R, G combinations)
4. Verify type values match existing categories

### Documentation

When adding custom tokens, consider documenting:
- **Why was this token added?** (Missing from Cockatrice, custom variant, etc.)
- **Source:** Where does this token come from? (Specific set, custom design, etc.)
- **Date added:** When was this token added to the custom list?

**Example with comments (not valid JSON, for documentation only):**
```javascript
// Added 2025-01-15: Missing from Cockatrice XML
// Source: Murders at Karlov Manor
{
  "name": "Clue",
  "pt": "",
  "colors": "",
  "abilities": "{2}, Sacrifice this artifact: Draw a card.",
  "type": "Artifact"
}
```

Since JSON doesn't support comments, maintain a separate `CUSTOM_TOKEN_CHANGELOG.md` file with explanations.

## Example Scenarios

### Scenario 1: Add a Token Missing from Cockatrice

**Problem:** A recent set has a token that hasn't been added to Cockatrice XML yet.

**Solution:**
```json
{
  "name": "Dinosaur",
  "pt": "3/3",
  "colors": "RG",
  "abilities": "Trample",
  "type": "Creature"
}
```

### Scenario 2: Fix Incorrect Abilities Text

**Problem:** Auto-generated token has incorrect abilities formatting.

**Solution:** Add custom token with exact name/pt/colors/type to override, with corrected abilities text.

### Scenario 3: Add a Custom Variant

**Problem:** Need a specific token variant for testing or personal use.

**Solution:**
```json
{
  "name": "Test Token",
  "pt": "10/10",
  "colors": "WUBRG",
  "abilities": "Testing only - do not use in production",
  "type": "Creature"
}
```

## Regenerating the Database

After modifying `custom_tokens.json`:

1. Run the script:
   ```bash
   python3 docs/housekeeping/process_tokens_with_popularity.py
   ```

2. Verify output:
   - Check `assets/token_database.json` for your custom tokens
   - Confirm token count increased appropriately
   - Test in the app by searching for your custom token

3. Commit changes:
   ```bash
   git add docs/housekeeping/custom_tokens.json assets/token_database.json
   git commit -m "Add custom tokens: [description]"
   ```

## Troubleshooting

### Custom tokens not appearing in final database

**Causes:**
- JSON syntax error in `custom_tokens.json`
- Script not modified to load custom tokens
- Custom token has invalid fields
- Deduplication removed it (check composite ID)

**Solutions:**
- Validate JSON syntax
- Verify script integration code is present
- Check script output for error messages
- Print token list before/after deduplication to debug

### Custom token overridden by auto-generated token

**Cause:** Merge order is reversed (generated tokens added after custom tokens)

**Solution:** Ensure custom tokens are appended **after** generated tokens in the merge step

### Invalid color codes or type values

**Cause:** Custom token uses non-standard values

**Solution:** Use only valid MTG color codes (W, U, B, R, G) and standard type values (Creature, Artifact, Enchantment, Emblem, etc.)
