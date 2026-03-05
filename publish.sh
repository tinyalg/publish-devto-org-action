#!/bin/bash

# ==============================================================================
# Usage:
#   export DEVTO_API_KEY="your_api_key_here"
#   ./publish.sh <path_to_markdown_file>
#
# Description:
#   Publishes/updates an article to Dev.to.
#   - If 'organization_username: <name>' is in front matter, posts to that org.
#   - Otherwise, posts as a personal article.
#   - Extracts 'id' and 'published' from front matter.
#   - Defaults 'published' to false.
#   - Automatically writes back the Article ID upon creation.
# ==============================================================================

FILE_PATH=$1

# Function to display usage instructions
usage() {
    echo "Usage: $0 <file_path>"
    echo "Required Environment Variable: DEVTO_API_KEY"
    exit 1
}

if [ -z "$FILE_PATH" ] || [ -z "$DEVTO_API_KEY" ]; then
    usage
fi

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' not found."
    exit 1
fi

# 1. Extract Article ID
ARTICLE_ID=$(head -n 20 "$FILE_PATH" | grep -Ei "^id:[[:space:]]*[0-9]+" | head -n 1 | sed 's/[^0-9]//g')

# 2. Extract 'published' status
EXTRACTED_PUB=$(head -n 20 "$FILE_PATH" | grep -Ei "^published:[[:space:]]*(true|false)" | head -n 1 | awk '{print tolower($2)}' | xargs)

if [ "$EXTRACTED_PUB" = "true" ]; then
    PUBLISHED_VALUE=true
else
    PUBLISHED_VALUE=false
fi

# 3. Extract Organization username (e.g., "organization_username: tinyalg")
ORG_USERNAME=$(head -n 20 "$FILE_PATH" | grep -Ei "^organization_username:[[:space:]]*[a-zA-Z0-9_-]+" | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d ' "\047')

# 4. Determine Organization ID
TARGET_ORG_ID=""
if [ -n "$ORG_USERNAME" ]; then
    echo ">>> Resolving Organization ID for username: '$ORG_USERNAME'..."
    ORG_API_RES=$(curl -s "https://dev.to/api/organizations/$ORG_USERNAME")
    FETCHED_ORG_ID=$(echo "$ORG_API_RES" | grep -Eo '"id":[0-9]+' | head -n 1 | cut -d: -f2)
    
    if [ -n "$FETCHED_ORG_ID" ]; then
        TARGET_ORG_ID=$FETCHED_ORG_ID
        echo "    -> Found Organization ID: $TARGET_ORG_ID"
    else
        echo "Error: Could not find Organization '$ORG_USERNAME' on Dev.to."
        exit 1
    fi
else
    echo ">>> No organization_username found. Will publish as a personal post."
fi

# 5. Read Markdown content
BODY_CONTENT=$(cat "$FILE_PATH")

# 6. Build JSON payload
# Omit organization_id completely if TARGET_ORG_ID is empty
JSON_PAYLOAD=$(jq -n \
    --arg body "$BODY_CONTENT" \
    --arg org "$TARGET_ORG_ID" \
    --argjson pub "$PUBLISHED_VALUE" \
    'if $org == "" then
        {
            "article": {
                "body_markdown": $body,
                "published": $pub
            }
        }
    else
        {
            "article": {
                "body_markdown": $body,
                "published": $pub,
                "organization_id": ($org | tonumber)
            }
        }
    end')

# 7. Determine Method and URL
if [ -n "$ARTICLE_ID" ]; then
    echo ">>> Mode: Update (Article ID: $ARTICLE_ID, Published: $PUBLISHED_VALUE)"
    METHOD="PUT"
    URL="https://dev.to/api/articles/$ARTICLE_ID"
else
    echo ">>> Mode: New Publication (Published: $PUBLISHED_VALUE)"
    METHOD="POST"
    URL="https://dev.to/api/articles"
fi

# 8. Execute API Request
# 8. Execute API Request
if [ "$DRY_RUN" = "true" ]; then
    echo "=========================================="
    echo "🚨 DRY RUN MODE ENABLED 🚨"
    echo "Would execute: $METHOD $URL"
    echo "Payload to send:"
    echo "$JSON_PAYLOAD" | jq .
    echo "=========================================="
    
    # Simulate a successful Dev.to API response
    if [ -z "$ARTICLE_ID" ]; then
        MOCK_ID=$((RANDOM % 10000 + 9000000)) # 生成テスト用の適当なダミーID
        RESPONSE="{\"id\":$MOCK_ID, \"url\":\"https://dev.to/mock/article-$MOCK_ID\"}"
    else
        RESPONSE="{\"id\":$ARTICLE_ID, \"url\":\"https://dev.to/mock/article-$ARTICLE_ID\"}"
    fi
else
    RESPONSE=$(curl -s -X "$METHOD" "$URL" \
        -H "Content-Type: application/json" \
        -H "api-key: $DEVTO_API_KEY" \
        -d "$JSON_PAYLOAD")

# 9. Parse and Update File
# Dev.to API may return unescaped control characters, which breaks jq.
# We use grep to safely extract the ID and URL directly as text.
NEW_ID=$(echo "$RESPONSE" | grep -Eo '"id":[0-9]+' | head -n 1 | cut -d: -f2)
ARTICLE_URL=$(echo "$RESPONSE" | grep -Eo '"url":"[^"]+"' | head -n 1 | cut -d'"' -f4)

if [ -n "$NEW_ID" ]; then
    if [ -z "$ARTICLE_ID" ]; then
        # For new posts, insert the ID safely into the second line
        {
            head -n 1 "$FILE_PATH"
            echo "id: $NEW_ID"
            tail -n +2 "$FILE_PATH"
        } > "${FILE_PATH}.tmp" && mv "${FILE_PATH}.tmp" "$FILE_PATH"
        
        echo "Success: Created with ID $NEW_ID"
    else
        echo "Success: Updated Article $ARTICLE_ID"
    fi
    echo "URL: $ARTICLE_URL"
else
    echo "Error: API call failed or returned an unexpected format."
    echo "$RESPONSE" | jq . || echo "$RESPONSE"
    exit 1
fi