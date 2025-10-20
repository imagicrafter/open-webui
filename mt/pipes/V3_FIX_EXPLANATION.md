# Version 3 Fix - JSON-Aware Parsing

## Root Cause Found

Your DO agent is **already returning JSON** when asked for follow-ups, even though the pipe's system prompt says "Return them as a simple list, one per line."

### Evidence from Trace Logs

**Follow-up task output:**
```json
{"follow_ups": ["How do I combine multiple filters, like hail_damage OR wind_damage, in a single query?", ...]}
```

The DO agent ignored the "one per line" instruction and returned valid JSON.

## What Was Happening in Previous Versions

### Version 1 & Fixed Version (do-function-pipe_fixed_followups.py)

```python
lines = content.strip().split('\n')
# content = '{"follow_ups": ["Q1", "Q2", "Q3"]}'
# lines = ['{"follow_ups": ["Q1", "Q2", "Q3"]}']  ← Only one "line"!

for line in lines:
    cleaned = clean_up(line)
    follow_ups.append(cleaned)

# Result: follow_ups = ['{"follow_ups": ["Q1", "Q2", "Q3"]}']
#                       ↑ The entire JSON string as ONE element!

json_content = json.dumps({"follow_ups": follow_ups})
# Result: '{"follow_ups": ["{\"follow_ups\": [\"Q1\", \"Q2\", \"Q3\"]}"]}'
#                          ↑ JSON nested inside JSON!
```

### What Middleware Received

```python
# Middleware extracts:
follow_ups_string = '{"follow_ups": ["{\"follow_ups\": [\"Q1\", \"Q2\", \"Q3\"]}"]}'
parsed = json.loads(follow_ups_string)
follow_ups = parsed["follow_ups"]
# Result: ['{"follow_ups": ["Q1", "Q2", "Q3"]}']
#         ↑ Array with ONE element: a JSON string!
```

### What Frontend Displayed

The FollowUps Svelte component receives:
```javascript
followUps = ['{"follow_ups": ["Q1", "Q2", "Q3"]}']
```

It renders this as text since it's expecting plain strings like `["Question 1", "Question 2"]`

## Version 3 Fix

### New Logic: Try JSON First, Then Line Parsing

```python
def _extract_follow_ups(content, task_body):
    # FIRST: Try parsing as JSON (DO agent might return this)
    try:
        json_start = content.find("{")
        json_end = content.rfind("}") + 1

        if json_start != -1 and json_end > json_start:
            json_str = content[json_start:json_end]
            parsed = json.loads(json_str)

            if "follow_ups" in parsed:
                return parsed["follow_ups"]  # ← Extract array directly!
    except Exception:
        pass

    # FALLBACK: Parse as plain text lines (if DO agent follows instructions)
    follow_ups = []
    for line in content.split('\n'):
        cleaned = clean_up(line)
        if cleaned and not looks_like_json(cleaned):
            follow_ups.append(cleaned)

    return follow_ups
```

### What Gets Returned

```python
# DO agent returns: '{"follow_ups": ["Q1", "Q2", "Q3"]}'
# _extract_follow_ups() returns: ["Q1", "Q2", "Q3"]
# Pipe returns to backend: '{"follow_ups": ["Q1", "Q2", "Q3"]}'  ← Correct!
```

### What Middleware Receives

```python
follow_ups_string = '{"follow_ups": ["Q1", "Q2", "Q3"]}'
parsed = json.loads(follow_ups_string)
follow_ups = parsed["follow_ups"]
# Result: ["Q1", "Q2", "Q3"]  ← Clean array of questions!
```

### What Frontend Displays

```javascript
followUps = ["Q1", "Q2", "Q3"]
```

✅ Clickable buttons appear correctly!

## Why This Works

1. **DO agent behavior:** Returns JSON regardless of instructions
2. **V3 adaptation:** Detects and parses JSON directly
3. **No double-nesting:** Extracts the array before re-packaging
4. **Backward compatible:** Falls back to line parsing if DO agent changes behavior

## Testing Version 3

1. Install `do-function-pipe-v3-json-aware.py`
2. Set as both chat model and task model
3. Enable DEBUG_MODE valve to see parsing logic
4. Send a test message
5. Verify:
   - ✅ Title updates correctly
   - ✅ Follow-up questions appear as clickable buttons
   - ✅ No JSON text in chat content

## Key Difference from V2

**V2:** Assumed plain text lines → Failed when DO agent returned JSON
**V3:** Tries JSON first → Handles actual DO agent behavior correctly
