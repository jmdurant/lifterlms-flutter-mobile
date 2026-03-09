# LifterLMS MCP Server

An MCP (Model Context Protocol) server that lets AI assistants create and manage LifterLMS courses with slide-based presentations, narration scripts, quizzes, and CME configurations — or import existing PowerPoint files as courses.

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

You also need the **LifterLMS Mobile App** WordPress plugin activated, which provides the custom REST endpoints for slides, scripts, and CME.

### 3. Add to Claude Code

Add this to your `.claude/settings.json` or project `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "lifterlms": {
      "command": "node",
      "args": ["C:/path/to/mcp-lifterlms/index.js"],
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
- **get_course** — Get course details with sections and lessons
- **create_course** — Create a new course
- **update_course** — Update course title, content, status
- **delete_course** — Move a course to trash

### Course Structure
- **create_section** — Create a section within a course
- **create_lesson** — Create a lesson with slides, narration scripts, video/audio embeds
- **create_quiz** — Create a quiz with questions and attach to a lesson

### CME Configuration
- **configure_cme** — Set up CME credits for a course (credit type, hours, attestation, evaluation)

### One-Shot Course Creation
- **scaffold_course** — Create an entire course in one call: course → sections → lessons (with slides + scripts) → quizzes → CME config
- **import_powerpoint** — Import a `.pptx` file as a course, extracting slides and speaker notes as narration scripts

### Student Management
- **list_students** — List students (with search)
- **enroll_student** — Enroll a student in a course

---

## Creating Courses

### Method 1: Scaffold from a Prompt (One-Shot)

Ask Claude to create a course and it uses `scaffold_course` to build everything at once:

> "Create a 5-lesson CME course on Diabetes Management. Each lesson should have a slide presentation with narration scripts. Include a quiz at the end of each lesson. Award 2.0 AMA PRA Category 1 credits."

This creates:
- The course in LifterLMS
- Sections and lessons
- Slide decks per lesson (swipeable cards in the mobile app)
- Per-slide narration scripts (what to say on each slide)
- Quizzes with questions
- CME credit configuration with ACCME-required disclosure and objectives slides

### Method 2: Import a PowerPoint

If you already have a PowerPoint presentation, import it directly:

> "Import `C:/presentations/cardiac-emergencies.pptx` as a CME course with 1.5 AMA PRA Category 1 credits, 10 slides per lesson"

The `import_powerpoint` tool:
- Parses the `.pptx` file
- Extracts slide titles, bullet points, and body text
- Converts **speaker notes → narration scripts** for each slide
- Auto-detects slide layout (title + bullets, title + body, title + image, full image)
- Splits into multiple lessons if `slides_per_lesson` is set
- Auto-prepends ACCME disclosure and learning objectives slides if CME is configured

### Method 3: Build Step by Step

For more control, use individual tools in sequence:

1. `create_course` — Create the course shell
2. `create_section` — Add sections (modules)
3. `create_lesson` — Add lessons with slides and scripts
4. `create_quiz` — Attach quizzes to lessons
5. `configure_cme` — Set up CME credits

---

## Slide Format

Each lesson can have a slide deck that renders as swipeable cards in the mobile app. Slides support 4 layouts:

| Layout | Description |
|--------|-------------|
| `title_bullets` | Title with bullet point list (default) |
| `title_body` | Title with paragraph text |
| `title_image` | Title with an image below |
| `full_image` | Full-bleed image with title overlay |

### Slide Schema

```json
{
  "title": "Slide Title",
  "layout": "title_bullets",
  "bullets": ["Point 1", "Point 2", "Point 3"],
  "body": "Optional paragraph text (for title_body layout)",
  "image_url": "https://example.com/image.jpg",
  "background_color": "#1a73e8",
  "script": "Narration text for this slide — what the presenter would say"
}
```

When no slides exist for a lesson, the app falls back to rendering the lesson's HTML content.

---

## CME (Continuing Medical Education)

When CME is configured on a course, every lesson's slide deck automatically gets two slides prepended at the beginning:

1. **Disclosures** — Faculty name, financial disclosure statement, accreditation statement, credit type/hours
2. **Learning Objectives** — Bulleted list of course learning objectives

This satisfies ACCME requirements for disclosure and objectives before educational content.

### CME Configuration Options

| Field | Description |
|-------|-------------|
| `credit_type` | `ama_pra_1`, `ama_pra_2`, `ancc`, `acpe`, `aafp`, `aapa`, `moc`, `ce`, `ceu`, `custom` |
| `credit_hours` | Number of credit hours (e.g., `1.5`) |
| `faculty_name` | Presenter/faculty name for disclosure slide |
| `disclosure_text` | Financial disclosure statement |
| `learning_objectives` | Array of objective strings |
| `accreditation_statement` | Accreditation body statement |
| `expiration_months` | Credit expiration period |
| `attestation_required` | Require attestation for credit (default: true) |
| `evaluation_required` | Require post-activity evaluation (default: true) |

---

## Example Prompts

**Basic course:**
> "Create a draft course called 'Introduction to Pharmacology' with 3 lessons covering drug classifications, pharmacokinetics, and drug interactions. Add slides and narration for each."

**CME course with full config:**
> "Create a CME course on Sepsis Management. 4 lessons with slide presentations. Faculty: Dr. Jane Smith. Disclosure: No relevant financial relationships. Learning objectives: 1) Identify early signs of sepsis, 2) Apply the Sepsis-3 criteria, 3) Initiate the 1-hour bundle, 4) Manage fluid resuscitation. Award 2.0 AMA PRA Category 1 credits with attestation and evaluation required."

**PowerPoint import:**
> "Import the PowerPoint at `C:/Users/docto/Documents/wound-care.pptx` as a course. Split it into lessons of 12 slides each. Configure as 1.0 ANCC credit."

**Quiz creation:**
> "Add a 10-question quiz to lesson 42. Mix of multiple choice and true/false. 80% passing score. 15 minute time limit."

**Student management:**
> "Enroll all students with 'nursing' in their name into course 15."
