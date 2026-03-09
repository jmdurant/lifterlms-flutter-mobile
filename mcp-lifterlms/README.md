# LifterLMS MCP Server

An MCP (Model Context Protocol) server that lets AI assistants create and manage LifterLMS courses, sections, lessons, quizzes, and CME configurations.

## Setup

### 1. Install dependencies

```bash
cd mcp-lifterlms
npm install
```

### 2. Configure LifterLMS API credentials

You need a LifterLMS REST API consumer key/secret. Generate one in WordPress at:
**WP Admin → LifterLMS → Settings → REST API → Add Key**

Set permissions to **Read/Write**.

### 3. Add to Claude Code

Add this to your `.claude/settings.json` or project `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "lifterlms": {
      "command": "node",
      "args": ["C:/Users/docto/lifterlms-flutter-mobile/mcp-lifterlms/index.js"],
      "env": {
        "LIFTERLMS_SITE_URL": "https://your-site.com",
        "LIFTERLMS_CONSUMER_KEY": "ck_your_key_here",
        "LIFTERLMS_CONSUMER_SECRET": "cs_your_secret_here"
      }
    }
  }
}
```

## Available Tools

### Course Management
- **list_courses** — List existing courses (with search/pagination)
- **get_course** — Get course details with sections
- **create_course** — Create a new course
- **update_course** — Update course title, content, status
- **delete_course** — Move a course to trash

### Course Structure
- **create_section** — Create a section within a course
- **create_lesson** — Create a lesson within a section (supports video/audio embeds)
- **create_quiz** — Create a quiz with questions and attach to a lesson

### CME Configuration
- **configure_cme** — Set up CME credits for a course (credit type, hours, attestation, evaluation)

### Scaffolding
- **scaffold_course** — Create an entire course structure in one call (course → sections → lessons → quizzes → CME) from a single description

### Student Management
- **list_students** — List students (with search)
- **enroll_student** — Enroll a student in a course

## Example Usage

Once configured, you can ask Claude things like:

> "Create a 3-module CME course on infection control. Each module should have 3 lessons and a quiz. Award 3.0 AMA PRA Category 1 credits with attestation required."

The `scaffold_course` tool handles the entire creation in one call, or the AI can use individual tools for more control.
