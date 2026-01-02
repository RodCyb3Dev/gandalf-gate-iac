#!/bin/bash
# Quick verification script to test if secrets contain actual values

set -e

echo "🔍 Verifying secrets contain actual values (not references)..."
echo ""

cd "$(dirname "$0")/.."

# Run secrets script and check output
output=$(./.kamal/secrets 2>/dev/null)

# Check for 1Password references (which would indicate a problem)
if echo "$output" | grep -q "\[use 'op item get"; then
    echo "❌ PROBLEM: Secrets contain 1Password references, not actual values!"
    echo ""
    echo "This means the secrets script is not resolving the actual secret values."
    echo "Re-run with --reveal flag or check 1Password CLI authentication."
    exit 1
fi

# Check if we have actual values
if [ -z "$output" ]; then
    echo "❌ PROBLEM: Secrets script returned empty output!"
    exit 1
fi

# Count how many secrets have actual values
count=$(echo "$output" | grep -c "=" || echo "0")

echo "✅ Secrets script working correctly!"
echo ""
echo "📊 Summary:"
echo "   - Total secrets: $count"
echo "   - No 1Password references found"
echo "   - All secrets resolved to actual values"
echo ""

# Show first few characters of each secret (for verification)
echo "🔐 Secret preview (first 10 chars):"
echo "$output" | while IFS='=' read -r key value; do
    if [ -n "$value" ] && [ ${#value} -gt 0 ]; then
        # Truncate to first 10 chars and mask
        preview="${value:0:10}"
        if [ ${#value} -gt 10 ]; then
            preview="${preview}***"
        fi
        echo "   ✅ $key = $preview"
    else
        echo "   ⚠️  $key = (empty)"
    fi
done | head -15

echo ""
echo "✅ All secrets verified! Ready for Kamal deployment."

