# Publish to Dev.to Organization Action

A GitHub Action to publish and update Markdown articles to Dev.to, featuring **native Organization support** and **smart ID management**.

## 🤔 Why this Action?

While existing actions (like `sinedied/publish-devto`) are great for personal blogs, they lack the ability to publish directly to Dev.to Organizations. This action solves that exact problem. 

By simply adding `organization_username` to your markdown's front matter, this action will automatically resolve the ID and publish it to your organization. It also writes the generated article `id` back to your file, ensuring future runs update the existing post instead of creating duplicates.

## ✨ Features

- 🏢 **Organization Support**: Automatically resolves your organization from the front matter.
- 🔄 **Smart Updates**: Writes the Dev.to `id` back to your markdown file after the first publish.
- 👤 **Personal Fallback**: If no organization is specified, it smoothly falls back to publishing to your personal account.
- 📝 **Draft Control**: Respects `published: true` or `false` in your front matter.
- ⏱️ **Rate Limit Safe**: Automatically includes a 5-second delay between requests when publishing multiple articles to prevent Forem API rate-limit errors.
- 🧪 **Dry Run Mode**: Test your workflow and see exactly what JSON payload will be sent without making actual API calls to Dev.to.

---

## 📖 Usage

### 1. Configure your Markdown Front Matter
Add `organization_username` to the top of your markdown file. 

```markdown
---
title: My Awesome Article
published: false
organization_username: your_organization_username
---

Your article content goes here...
```

*(Note: After the first run, the action will automatically insert `id: <number>` into this front matter.)*

### 2. Add the Workflow

Create a `.github/workflows/publish.yml` file in your repository. Since this action modifies your markdown file (to save the article ID), we highly recommend pairing it with `git-auto-commit-action`.

```yaml
name: Publish to Dev.to

on:
  push:
    branches:
      - main
    paths:
      - 'posts/**.md' # Trigger workflow when markdown files in the posts directory change

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write # Required to commit the generated ID back to the repository
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          # Fetch all history so that changed-files can determine the diff
          fetch-depth: 0

      # Step to identify which files in 'posts/' were modified/created
      - name: Get changed files
        id: changed-files
        uses: tj-actions/changed-files@v47
        with:
          files: posts/*.md

      # Only run this step if there are actually changed markdown files
      - name: Publish Articles
        if: steps.changed-files.outputs.any_changed == 'true'
        uses: tinyalg/publish-devto-org-action@main
        with:
          devto_api_key: ${{ secrets.DEVTO_API_KEY }}
          # Pass only the changed files (space-separated list) to your action
          file_path: ${{ steps.changed-files.outputs.all_changed_files }}

      # Commit the updated files with newly assigned Dev.to IDs
      - name: Commit Article IDs
        if: steps.changed-files.outputs.any_changed == 'true'
        uses: stefanzweifel/git-auto-commit-action@v7
        with:
          commit_message: "chore: update Dev.to article IDs [skip ci]"
          file_pattern: 'posts/*.md'
```

### 🧪 Testing with Dry Run (Safe Mode)

Want to verify your setup without accidentally publishing to Dev.to? You can enable `dry_run` mode. This will process your files and print the exact JSON payload and target API endpoint to the GitHub Actions log, but **will not** send any data to Dev.to.

```yaml
      - name: Test Publish Articles
        uses: tinyalg/publish-devto-org-action@main
        with:
          devto_api_key: ${{ secrets.DEVTO_API_KEY }}
          file_path: 'posts/*.md'
          dry_run: 'true' # Enable dry run mode

```

*(Note: Even in dry run mode, the action will simulate a successful response and write a mock `id` to your markdown file, allowing you to fully test the git-auto-commit step as well!)*


## ⚙️ Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `devto_api_key` | Your Dev.to API Key. Keep this safe in GitHub Secrets. | Yes | N/A |
| `file_path` | The path to the markdown file(s) to publish. Supports glob patterns (e.g., posts/*.md). | Yes | N/A |
| `dry_run` | **(NEW)** If `true`, simulates the process and prints the payload/URL in logs without sending data. | No | `false` |

## License

Distributed under the [BSD 3-Clause License](LICENSE).