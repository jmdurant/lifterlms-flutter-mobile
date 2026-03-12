import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fs from "fs/promises";
import { createWriteStream } from "fs";
import path from "path";
import JSZip from "jszip";
import xml2js from "xml2js";
import PptxGenJS from "pptxgenjs";
import PDFDocument from "pdfkit";

// ── Configuration ──────────────────────────────────────────────────────────────

const SITE_URL = process.env.LIFTERLMS_SITE_URL || "";
const CONSUMER_KEY = process.env.LIFTERLMS_CONSUMER_KEY || "";
const CONSUMER_SECRET = process.env.LIFTERLMS_CONSUMER_SECRET || "";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";
const UNSPLASH_ACCESS_KEY = process.env.UNSPLASH_ACCESS_KEY || "";

function getAuthHeader() {
  return "Basic " + Buffer.from(`${CONSUMER_KEY}:${CONSUMER_SECRET}`).toString("base64");
}

async function apiCall(method, endpoint, body = null) {
  const url = `${SITE_URL}/wp-json/${endpoint}`;
  const options = {
    method,
    headers: {
      Authorization: getAuthHeader(),
      "Content-Type": "application/json",
    },
  };
  if (body) options.body = JSON.stringify(body);

  const res = await fetch(url, options);
  const data = await res.json();

  if (!res.ok) {
    const msg = data?.message || data?.error || res.statusText;
    throw new Error(`API ${res.status}: ${msg}`);
  }
  return data;
}

// ── MCP Server ─────────────────────────────────────────────────────────────────

const server = new McpServer({
  name: "lifterlms",
  version: "1.0.0",
});

// ── Tool: list_courses ─────────────────────────────────────────────────────────

server.tool(
  "list_courses",
  "List existing LifterLMS courses",
  {
    per_page: z.number().optional().describe("Results per page (default 10)"),
    page: z.number().optional().describe("Page number"),
    search: z.string().optional().describe("Search term"),
  },
  async ({ per_page = 10, page = 1, search }) => {
    const params = new URLSearchParams({ per_page: String(per_page), page: String(page) });
    if (search) params.set("search", search);
    const courses = await apiCall("GET", `llms/v1/courses?${params}`);
    const list = Array.isArray(courses) ? courses : [];
    const summary = list.map((c) => ({
      id: c.id,
      title: c.title?.rendered || c.title,
      status: c.status,
      date_created: c.date_created,
    }));
    return { content: [{ type: "text", text: JSON.stringify(summary, null, 2) }] };
  }
);

// ── Tool: get_course ───────────────────────────────────────────────────────────

server.tool(
  "get_course",
  "Get details of a specific course including its sections and lessons",
  {
    course_id: z.number().describe("Course ID"),
  },
  async ({ course_id }) => {
    const course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    // Fetch sections
    let sections = [];
    try {
      sections = await apiCall("GET", `llms/v1/sections?parent=${course_id}&per_page=100`);
      if (!Array.isArray(sections)) sections = [];
    } catch (_) {}

    return {
      content: [{
        type: "text",
        text: JSON.stringify({ course, sections }, null, 2),
      }],
    };
  }
);

// ── Tool: create_course ────────────────────────────────────────────────────────

server.tool(
  "create_course",
  "Create a new LifterLMS course",
  {
    title: z.string().describe("Course title"),
    content: z.string().optional().describe("Course description/content (HTML)"),
    excerpt: z.string().optional().describe("Short description"),
    status: z.enum(["publish", "draft", "pending"]).optional().describe("Post status (default draft)"),
    catalog_visibility: z.enum(["catalog_search", "catalog", "search", "hidden"]).optional(),
  },
  async ({ title, content, excerpt, status = "draft", catalog_visibility }) => {
    const body = { title, status };
    if (content) body.content = content;
    if (excerpt) body.excerpt = excerpt;
    if (catalog_visibility) body.catalog_visibility = catalog_visibility;

    const course = await apiCall("POST", "llms/v1/courses", body);
    return {
      content: [{
        type: "text",
        text: `Course created: ID ${course.id}, title "${course.title?.rendered || title}", status: ${course.status}`,
      }],
    };
  }
);

// ── Tool: update_course ────────────────────────────────────────────────────────

server.tool(
  "update_course",
  "Update an existing course",
  {
    course_id: z.number().describe("Course ID to update"),
    title: z.string().optional().describe("New title"),
    content: z.string().optional().describe("New content (HTML)"),
    excerpt: z.string().optional().describe("New excerpt"),
    status: z.enum(["publish", "draft", "pending"]).optional(),
  },
  async ({ course_id, ...updates }) => {
    const body = {};
    for (const [k, v] of Object.entries(updates)) {
      if (v !== undefined) body[k] = v;
    }
    const course = await apiCall("POST", `llms/v1/courses/${course_id}`, body);
    return {
      content: [{ type: "text", text: `Course ${course_id} updated successfully.` }],
    };
  }
);

// ── Tool: create_section ───────────────────────────────────────────────────────

server.tool(
  "create_section",
  "Create a section within a course",
  {
    title: z.string().describe("Section title"),
    parent_id: z.number().describe("Parent course ID"),
    order: z.number().optional().describe("Position order within the course"),
  },
  async ({ title, parent_id, order }) => {
    const body = { title, parent_id };
    if (order !== undefined) body.order = order;

    const section = await apiCall("POST", "llms/v1/sections", body);
    return {
      content: [{
        type: "text",
        text: `Section created: ID ${section.id}, title "${title}" in course ${parent_id}`,
      }],
    };
  }
);

// ── Tool: create_lesson ────────────────────────────────────────────────────────

server.tool(
  "create_lesson",
  "Create a lesson within a section",
  {
    title: z.string().describe("Lesson title"),
    parent_id: z.number().describe("Parent section ID"),
    content: z.string().optional().describe("Lesson content (HTML) - used as fallback if no slides provided"),
    excerpt: z.string().optional().describe("Lesson excerpt"),
    order: z.number().optional().describe("Position order within the section"),
    video_embed: z.string().optional().describe("Video embed URL"),
    audio_embed: z.string().optional().describe("Audio embed URL"),
    script: z.string().optional().describe("Single narration script for the whole lesson (use slides[].script for per-slide scripts instead)"),
    slides: z.array(z.object({
      title: z.string().describe("Slide title/heading"),
      layout: z.enum(["title_bullets", "title_body", "title_image", "full_image"]).optional().describe("Slide layout (default title_bullets)"),
      bullets: z.array(z.string()).optional().describe("Bullet points for the slide"),
      body: z.string().optional().describe("Paragraph text for the slide"),
      image_url: z.string().optional().describe("Image URL for the slide"),
      background_color: z.string().optional().describe("Hex color for slide background (e.g. #1a73e8)"),
      script: z.string().optional().describe("Narration script for this specific slide - what the presenter reads aloud"),
    })).optional().describe("Slide deck for the lesson. Each slide has its own content and narration script. When slides are provided, the app displays a swipeable card deck instead of scrolling HTML."),
  },
  async ({ title, parent_id, content, excerpt, order, video_embed, audio_embed, script, slides }) => {
    const body = { title, parent_id };
    if (content) body.content = content;
    if (excerpt) body.excerpt = excerpt;
    if (order !== undefined) body.order = order;
    if (video_embed) body.video_embed = video_embed;
    if (audio_embed) body.audio_embed = audio_embed;

    const lesson = await apiCall("POST", "llms/v1/lessons", body);
    const extras = [];

    // Save slides if provided
    if (slides && slides.length > 0) {
      try {
        await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/slides`, { slides });
        extras.push(`${slides.length} slides`);
      } catch (err) {
        extras.push(`slides failed: ${err.message}`);
      }
    }

    // Save single script if provided (and no per-slide scripts)
    if (script) {
      try {
        await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/script`, { script });
        extras.push("narration script");
      } catch (_) {}
    }

    return {
      content: [{
        type: "text",
        text: `Lesson created: ID ${lesson.id}, title "${title}" in section ${parent_id}` +
          (extras.length > 0 ? ` (with ${extras.join(", ")})` : ""),
      }],
    };
  }
);

// ── Tool: create_quiz ──────────────────────────────────────────────────────────

server.tool(
  "create_quiz",
  "Create a quiz and attach it to a lesson. The quiz is created via the LifterLMS API and linked to the specified lesson.",
  {
    title: z.string().describe("Quiz title"),
    lesson_id: z.number().describe("Lesson ID to attach the quiz to"),
    passing_percent: z.number().optional().describe("Passing percentage (default 65)"),
    time_limit: z.number().optional().describe("Time limit in minutes (0 = unlimited)"),
    allowed_attempts: z.number().optional().describe("Number of allowed attempts (0 = unlimited)"),
    questions: z.array(z.object({
      title: z.string().describe("Question text"),
      type: z.enum(["choice", "true_false", "blank", "reorder", "long_answer", "short_answer"]).describe("Question type"),
      points: z.number().optional().describe("Points for this question (default 1)"),
      choices: z.array(z.object({
        choice: z.string().describe("Choice text"),
        correct: z.boolean().optional().describe("Is this the correct answer?"),
      })).optional().describe("Answer choices (for choice/true_false types)"),
    })).optional().describe("Array of quiz questions"),
  },
  async ({ title, lesson_id, passing_percent = 65, time_limit = 0, allowed_attempts = 0, questions = [] }) => {
    // Create the quiz post via WordPress API (quizzes are a custom post type)
    const quizBody = {
      title,
      status: "publish",
    };
    const quiz = await apiCall("POST", "llms/v1/quizzes", quizBody);
    const quizId = quiz.id;

    // Update quiz settings
    await apiCall("POST", `llms/v1/quizzes/${quizId}`, {
      lesson_id,
      passing_percent,
      time_limit,
      allowed_attempts,
    });

    // Create questions
    const createdQuestions = [];
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      const questionBody = {
        title: q.title,
        question_type: q.type,
        parent_id: quizId,
        points: q.points || 1,
        order: i + 1,
      };

      try {
        const question = await apiCall("POST", "llms/v1/questions", questionBody);

        // Add choices if applicable
        if (q.choices && q.choices.length > 0) {
          for (const choice of q.choices) {
            try {
              await apiCall("POST", `llms/v1/questions/${question.id}/choices`, {
                choice: choice.choice,
                correct: choice.correct || false,
              });
            } catch (_) {}
          }
        }

        createdQuestions.push({ id: question.id, title: q.title });
      } catch (err) {
        createdQuestions.push({ title: q.title, error: err.message });
      }
    }

    return {
      content: [{
        type: "text",
        text: `Quiz created: ID ${quizId}, title "${title}", attached to lesson ${lesson_id}\n` +
          `Settings: passing=${passing_percent}%, time_limit=${time_limit}min, attempts=${allowed_attempts}\n` +
          `Questions: ${JSON.stringify(createdQuestions, null, 2)}`,
      }],
    };
  }
);

// ── CME Helpers ────────────────────────────────────────────────────────────────

const CREDIT_LABELS = {
  ama_pra_1: "AMA PRA Category 1",
  ama_pra_2: "AMA PRA Category 2",
  ancc: "ANCC Contact Hours",
  acpe: "ACPE Credits",
  aafp: "AAFP Prescribed Credits",
  aapa: "AAPA Category 1 CME",
  moc: "MOC Points",
  ce: "CE Credits",
  ceu: "CEU Credits",
  custom: "Custom Credits",
};

const CME_CREDIT_SCHEMA = z.object({
  credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]),
  credit_hours: z.number(),
  expiration_months: z.number().optional(),
  accrediting_institution: z.string().optional().describe("Institution providing accreditation (e.g., 'Duke University School of Nursing', 'UNC School of Medicine')"),
  accreditation_statement: z.string().optional().describe("Accreditation statement specific to this credit type"),
});

function normalizeCmeToArray(cme) {
  if (!cme) return [];
  if (Array.isArray(cme)) return cme;
  return [cme];
}

function buildCreditSummaryLines(credits) {
  return credits.map((c) => {
    const label = CREDIT_LABELS[c.credit_type] || c.credit_type;
    const inst = c.accrediting_institution ? ` (${c.accrediting_institution})` : "";
    return `${c.credit_hours} ${label}${inst}`;
  });
}

// ── Tool: configure_cme ────────────────────────────────────────────────────────

server.tool(
  "configure_cme",
  "Configure CME credits for a course. Supports multiple credit types (e.g., AMA PRA Category 1 via UNC + ANCC Contact Hours via Duke) for dual-accredited courses.",
  {
    course_id: z.number().describe("Course ID"),
    credits: z.array(z.object({
      credit_type: z.enum([
        "ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom",
      ]).describe("CME credit type"),
      credit_hours: z.number().describe("Number of credit hours for this type"),
      expiration_months: z.number().optional().describe("Months until credits expire (0 = never)"),
      accrediting_institution: z.string().optional().describe("Institution providing this accreditation (e.g., 'UNC School of Medicine')"),
      accreditation_statement: z.string().optional().describe("Accreditation statement for this credit type"),
    })).describe("Array of credit types — one entry per accrediting body"),
    attestation_required: z.boolean().optional().describe("Require attestation before awarding credits (default: true)"),
    attestation_text: z.string().optional().describe("Attestation statement text"),
    evaluation_required: z.boolean().optional().describe("Require post-activity evaluation (default: true)"),
    disclosure_text: z.string().optional().describe("Faculty disclosure/conflict of interest text"),
  },
  async ({ course_id, credits, attestation_required = true, attestation_text, evaluation_required = true, disclosure_text }) => {
    // Store all credit types as JSON in post meta
    const metaUpdates = {
      _llms_cme_enabled: "yes",
      _llms_cme_credits: JSON.stringify(credits),
      // Primary credit type (first in array) for backward compatibility
      _llms_cme_credit_type: credits[0].credit_type,
      _llms_cme_credit_hours: String(credits[0].credit_hours),
      _llms_cme_expiration_months: String(credits[0].expiration_months || 0),
      _llms_cme_attestation_required: attestation_required ? "yes" : "no",
      _llms_cme_evaluation_required: evaluation_required ? "yes" : "no",
    };

    if (attestation_text) {
      metaUpdates._llms_cme_attestation_text = attestation_text;
    }
    if (disclosure_text) {
      metaUpdates._llms_cme_disclosure_text = disclosure_text;
    }

    // Update via WordPress post meta endpoint
    await apiCall("POST", `wp/v2/courses/${course_id}`, { meta: metaUpdates });

    const creditLines = buildCreditSummaryLines(credits);

    return {
      content: [{
        type: "text",
        text: `CME configured for course ${course_id}:\n` +
          `  Credits:\n${creditLines.map((l) => `    • ${l}`).join("\n")}\n` +
          `  Attestation required: ${attestation_required}\n` +
          `  Evaluation required: ${evaluation_required}`,
      }],
    };
  }
);

// ── Tool: scaffold_course ──────────────────────────────────────────────────────

server.tool(
  "scaffold_course",
  "Scaffold an entire course structure at once: creates the course, sections, lessons, and optionally quizzes and CME configuration. Returns the complete structure with all IDs.",
  {
    title: z.string().describe("Course title"),
    description: z.string().optional().describe("Course description"),
    status: z.enum(["publish", "draft"]).optional().describe("Course status (default draft)"),
    sections: z.array(z.object({
      title: z.string().describe("Section title"),
      lessons: z.array(z.object({
        title: z.string().describe("Lesson title"),
        content: z.string().optional().describe("Lesson content (HTML) - fallback if no slides"),
        script: z.string().optional().describe("Single narration script for whole lesson"),
        slides: z.array(z.object({
          title: z.string().describe("Slide title"),
          layout: z.enum(["title_bullets", "title_body", "title_image", "full_image"]).optional(),
          bullets: z.array(z.string()).optional(),
          body: z.string().optional(),
          image_url: z.string().optional(),
          background_color: z.string().optional(),
          script: z.string().optional().describe("Narration for this slide"),
        })).optional().describe("Slide deck - when provided, app shows swipeable cards"),
        video_embed: z.string().optional().describe("Video URL"),
        quiz: z.object({
          title: z.string().describe("Quiz title"),
          passing_percent: z.number().optional(),
          time_limit: z.number().optional(),
          questions: z.array(z.object({
            title: z.string(),
            type: z.enum(["choice", "true_false", "blank", "reorder", "long_answer", "short_answer"]),
            points: z.number().optional(),
            choices: z.array(z.object({
              choice: z.string(),
              correct: z.boolean().optional(),
            })).optional(),
          })).optional(),
        }).optional().describe("Optional quiz for this lesson"),
      })),
    })).describe("Course sections with nested lessons"),
    cme: z.object({
      credits: z.array(CME_CREDIT_SCHEMA).optional().describe("Array of credit types for dual/multi-accredited courses (e.g., AMA PRA Cat 1 via UNC + ANCC via Duke)"),
      credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]).optional().describe("Single credit type (use 'credits' array for multi-accredited courses)"),
      credit_hours: z.number().optional(),
      expiration_months: z.number().optional(),
      attestation_required: z.boolean().optional(),
      evaluation_required: z.boolean().optional(),
      disclosure_text: z.string().optional().describe("Faculty disclosure statement (ACCME/ANCC requirement)"),
      learning_objectives: z.array(z.string()).optional().describe("Course-level learning objectives shown at start of each lesson"),
      faculty_name: z.string().optional().describe("Faculty/presenter name for disclosure slide"),
      accreditation_statement: z.string().optional().describe("Accreditation statement (legacy single-credit mode)"),
    }).optional().describe("Optional CME credit configuration — supports single or multiple credit types for dual-accredited courses"),
    auto_images: z.boolean().optional().describe("Auto-generate images for each lesson using Unsplash/Gemini and attach as featured image + inline content (default: false)"),
    image_source: z.enum(["auto", "gemini", "unsplash"]).optional().describe("Image source when auto_images is true (default: auto)"),
    image_style_hint: z.string().optional().describe("Style hint for image generation (e.g., 'clinical photography', 'medical illustrations')"),
    auto_videos: z.boolean().optional().describe("Auto-generate a short intro video for each lesson using Veo 3.1 AI and embed at top of content (default: false)"),
    video_duration: z.number().optional().describe("Duration per auto-generated video in seconds: 4, 6, or 8 (default: 4)"),
    video_style_hint: z.string().optional().describe("Style hint for video generation (e.g., 'clinical setting, diverse medical professionals')"),
    video_fast: z.boolean().optional().describe("Use Veo fast model for quicker video generation (default: true)"),
  },
  async ({ title, description, status = "draft", sections, cme, auto_images = false, image_source = "auto", image_style_hint = "", auto_videos = false, video_duration = 4, video_style_hint = "", video_fast = true }) => {
    const result = { course: null, sections: [], errors: [] };

    // 1. Create course
    try {
      const courseBody = { title, status };
      if (description) courseBody.content = description;
      const course = await apiCall("POST", "llms/v1/courses", courseBody);
      result.course = { id: course.id, title };
    } catch (err) {
      return {
        content: [{ type: "text", text: `Failed to create course: ${err.message}` }],
      };
    }

    const courseId = result.course.id;

    // 1b. Auto-generate course cover image
    if (auto_images) {
      try {
        const coverPrompt = image_style_hint
          ? `${title}: ${image_style_hint}`
          : `${title}, professional medical education course cover image`;
        const coverName = title.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
        let coverUploaded = null;

        if (image_source === "unsplash" || image_source === "auto") {
          const stock = await searchUnsplash(coverPrompt);
          if (stock) {
            coverUploaded = await fetchAndUploadUrl(stock.url, `${coverName}-cover.jpg`);
            await triggerUnsplashDownload(stock.download_url);
          }
        }
        if (!coverUploaded && (image_source === "gemini" || image_source === "auto") && GEMINI_API_KEY) {
          const generated = await generateImageGemini(coverPrompt);
          if (generated) {
            const ext = generated.mimeType.includes("png") ? "png" : "jpg";
            coverUploaded = await uploadToWordPressMedia(
              Buffer.from(generated.base64, "base64"),
              `${coverName}-cover.${ext}`,
              generated.mimeType
            );
          }
        }
        if (coverUploaded) {
          await setFeaturedImage("courses", courseId, coverUploaded.id);
          result.course.cover_image = coverUploaded.url;
        }
      } catch (err) {
        result.errors.push(`Course cover image: ${err.message}`);
      }
    }

    // 2. Create sections and lessons
    for (let si = 0; si < sections.length; si++) {
      const sec = sections[si];
      const sectionResult = { title: sec.title, id: null, lessons: [] };

      try {
        const section = await apiCall("POST", "llms/v1/sections", {
          title: sec.title,
          parent_id: courseId,
          order: si + 1,
        });
        sectionResult.id = section.id;
      } catch (err) {
        result.errors.push(`Section "${sec.title}": ${err.message}`);
        result.sections.push(sectionResult);
        continue;
      }

      // Create lessons
      for (let li = 0; li < sec.lessons.length; li++) {
        const les = sec.lessons[li];
        const lessonResult = { title: les.title, id: null, quiz: null };

        try {
          const lessonBody = {
            title: les.title,
            parent_id: sectionResult.id,
            order: li + 1,
          };
          if (les.content) lessonBody.content = les.content;
          if (les.video_embed) lessonBody.video_embed = les.video_embed;

          const lesson = await apiCall("POST", "llms/v1/lessons", lessonBody);
          lessonResult.id = lesson.id;

          // Save slides if provided — auto-prepend CME disclosure & objectives
          if (les.slides && les.slides.length > 0) {
            try {
              const finalSlides = [];

              // Prepend CME-required slides when CME is configured
              if (cme) {
                // Normalize credits: support both single credit_type and credits array
                const cmeCredits = cme.credits && cme.credits.length > 0
                  ? cme.credits
                  : (cme.credit_type ? [{ credit_type: cme.credit_type, credit_hours: cme.credit_hours, accrediting_institution: null, accreditation_statement: cme.accreditation_statement }] : []);

                // Slide 1: Disclosure
                const disclosureBullets = [];
                if (cme.faculty_name) disclosureBullets.push(`Faculty: ${cme.faculty_name}`);
                disclosureBullets.push(cme.disclosure_text || "The faculty for this activity have no relevant financial relationships with ineligible companies to disclose.");

                // Add accreditation statements per credit type
                for (const credit of cmeCredits) {
                  if (credit.accreditation_statement) {
                    disclosureBullets.push(credit.accreditation_statement);
                  }
                }
                // Legacy single accreditation statement
                if (cmeCredits.length === 0 && cme.accreditation_statement) {
                  disclosureBullets.push(cme.accreditation_statement);
                }

                // Slide 2: Credits Available (shows all credit types)
                const creditLines = buildCreditSummaryLines(cmeCredits);
                if (creditLines.length > 0) {
                  disclosureBullets.push(""); // spacer
                  disclosureBullets.push("Credits available upon completion:");
                  disclosureBullets.push(...creditLines);
                } else if (cme.credit_type && cme.credit_hours) {
                  disclosureBullets.push(`Credit: ${cme.credit_hours} ${cme.credit_type.replace(/_/g, " ").toUpperCase()} hour(s)`);
                }

                const disclosureScript = cmeCredits.length > 1
                  ? "Before we begin, please review the following disclosure information. This activity is jointly accredited for multiple credit types as listed."
                  : "Before we begin, please review the following disclosure information as required by accreditation standards.";

                finalSlides.push({
                  title: "Disclosures & Accreditation",
                  layout: "title_bullets",
                  bullets: disclosureBullets.filter((b) => b !== ""),
                  background_color: "#1a237e",
                  script: disclosureScript,
                });

                // Slide 3: Learning Objectives
                if (cme.learning_objectives && cme.learning_objectives.length > 0) {
                  finalSlides.push({
                    title: "Learning Objectives",
                    layout: "title_bullets",
                    bullets: cme.learning_objectives,
                    background_color: "#0d47a1",
                    script: "At the conclusion of this activity, participants should be able to achieve the following objectives.",
                  });
                }
              }

              finalSlides.push(...les.slides);
              await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/slides`, { slides: finalSlides });
              lessonResult.slide_count = finalSlides.length;
            } catch (err) {
              result.errors.push(`Slides for "${les.title}": ${err.message}`);
            }
          }

          // Save narration script if provided (single script, no slides)
          if (les.script && (!les.slides || les.slides.length === 0)) {
            try {
              await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/script`, { script: les.script });
              lessonResult.has_script = true;
            } catch (_) {
              result.errors.push(`Script for "${les.title}": failed to save`);
            }
          }
        } catch (err) {
          result.errors.push(`Lesson "${les.title}": ${err.message}`);
          sectionResult.lessons.push(lessonResult);
          continue;
        }

        // Auto-generate and attach image if enabled
        if (auto_images && lessonResult.id) {
          try {
            const imgPrompt = image_style_hint
              ? `${les.title}: ${image_style_hint}`
              : les.title;
            const imgName = les.title.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
            const imgResult = await generateAndAttachImage(imgPrompt, imgName, image_source, lessonResult.id, "lessons");
            if (imgResult) {
              lessonResult.image = { url: imgResult.url, source: imgResult.source };
            }
          } catch (err) {
            result.errors.push(`Image for "${les.title}": ${err.message}`);
          }
        }

        // Auto-generate and attach video if enabled
        if (auto_videos && lessonResult.id && GEMINI_API_KEY) {
          try {
            const vidPrompt = video_style_hint
              ? `Short educational intro clip for a medical CME lesson titled "${les.title}". Style: ${video_style_hint}. Professional, no text overlays.`
              : `Short educational intro clip for a medical CME lesson titled "${les.title}". Professional clinical setting, modern healthcare, no text overlays.`;
            const vidName = les.title.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
            const uploaded = await generateAndUploadVideo(vidPrompt, `${vidName}-intro`, {
              durationSeconds: video_duration,
              aspectRatio: "16:9",
              fast: video_fast,
            });

            // Prepend video to lesson content
            const lesson = await apiCall("GET", `llms/v1/lessons/${lessonResult.id}`);
            const currentContent = lesson.content?.rendered || lesson.content || "";
            const videoHtml = buildVideoEmbed(uploaded.url);
            await apiCall("POST", `llms/v1/lessons/${lessonResult.id}`, {
              content: videoHtml + currentContent,
              video_embed: uploaded.url,
            });

            lessonResult.video = { url: uploaded.url, model: uploaded.model };
          } catch (err) {
            result.errors.push(`Video for "${les.title}": ${err.message}`);
          }
        }

        // Create quiz if specified
        if (les.quiz && lessonResult.id) {
          try {
            const quiz = await apiCall("POST", "llms/v1/quizzes", {
              title: les.quiz.title,
              status: "publish",
            });

            await apiCall("POST", `llms/v1/quizzes/${quiz.id}`, {
              lesson_id: lessonResult.id,
              passing_percent: les.quiz.passing_percent || 65,
              time_limit: les.quiz.time_limit || 0,
            });

            lessonResult.quiz = { id: quiz.id, title: les.quiz.title, questions: [] };

            // Create questions
            if (les.quiz.questions) {
              for (let qi = 0; qi < les.quiz.questions.length; qi++) {
                const q = les.quiz.questions[qi];
                try {
                  const question = await apiCall("POST", "llms/v1/questions", {
                    title: q.title,
                    question_type: q.type,
                    parent_id: quiz.id,
                    points: q.points || 1,
                    order: qi + 1,
                  });

                  if (q.choices) {
                    for (const choice of q.choices) {
                      try {
                        await apiCall("POST", `llms/v1/questions/${question.id}/choices`, {
                          choice: choice.choice,
                          correct: choice.correct || false,
                        });
                      } catch (_) {}
                    }
                  }

                  lessonResult.quiz.questions.push({ id: question.id, title: q.title });
                } catch (err) {
                  result.errors.push(`Question "${q.title}": ${err.message}`);
                }
              }
            }
          } catch (err) {
            result.errors.push(`Quiz "${les.quiz.title}": ${err.message}`);
          }
        }

        sectionResult.lessons.push(lessonResult);
      }

      result.sections.push(sectionResult);
    }

    // 3. Configure CME if specified
    if (cme) {
      try {
        // Normalize to credits array
        const cmeCredits = cme.credits && cme.credits.length > 0
          ? cme.credits
          : (cme.credit_type ? [{ credit_type: cme.credit_type, credit_hours: cme.credit_hours, expiration_months: cme.expiration_months }] : []);

        const metaUpdates = {
          _llms_cme_enabled: "yes",
          _llms_cme_credits: JSON.stringify(cmeCredits),
          // Primary credit (backward compat)
          _llms_cme_credit_type: cmeCredits[0]?.credit_type || cme.credit_type,
          _llms_cme_credit_hours: String(cmeCredits[0]?.credit_hours || cme.credit_hours),
          _llms_cme_expiration_months: String(cmeCredits[0]?.expiration_months || cme.expiration_months || 0),
          _llms_cme_attestation_required: (cme.attestation_required !== false) ? "yes" : "no",
          _llms_cme_evaluation_required: (cme.evaluation_required !== false) ? "yes" : "no",
        };
        if (cme.disclosure_text) metaUpdates._llms_cme_disclosure_text = cme.disclosure_text;

        await apiCall("POST", `wp/v2/courses/${courseId}`, { meta: metaUpdates });
        result.cme = {
          status: "configured",
          credits: buildCreditSummaryLines(cmeCredits),
        };
      } catch (err) {
        result.errors.push(`CME config: ${err.message}`);
      }
    }

    return {
      content: [{
        type: "text",
        text: JSON.stringify(result, null, 2),
      }],
    };
  }
);

// ── Tool: delete_course ────────────────────────────────────────────────────────

server.tool(
  "delete_course",
  "Delete a course (moves to trash)",
  {
    course_id: z.number().describe("Course ID to delete"),
  },
  async ({ course_id }) => {
    await apiCall("DELETE", `llms/v1/courses/${course_id}`);
    return {
      content: [{ type: "text", text: `Course ${course_id} moved to trash.` }],
    };
  }
);

// ── Tool: list_students ────────────────────────────────────────────────────────

server.tool(
  "list_students",
  "List enrolled students, optionally filtered by course",
  {
    per_page: z.number().optional().describe("Results per page"),
    page: z.number().optional(),
    search: z.string().optional().describe("Search by name or email"),
  },
  async ({ per_page = 10, page = 1, search }) => {
    const params = new URLSearchParams({ per_page: String(per_page), page: String(page) });
    if (search) params.set("search", search);
    const students = await apiCall("GET", `llms/v1/students?${params}`);
    const list = Array.isArray(students) ? students : [];
    const summary = list.map((s) => ({
      id: s.id,
      name: s.name,
      email: s.email,
      registered_date: s.registered_date,
    }));
    return { content: [{ type: "text", text: JSON.stringify(summary, null, 2) }] };
  }
);

// ── Tool: enroll_student ───────────────────────────────────────────────────────

server.tool(
  "enroll_student",
  "Enroll a student in a course. For multi-credit CME courses, specify credit_type to record which accreditation the learner is pursuing.",
  {
    student_id: z.number().describe("Student/user ID"),
    course_id: z.number().describe("Course ID"),
    credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]).optional().describe("CME credit type the learner selected (for multi-accredited courses)"),
  },
  async ({ student_id, course_id, credit_type }) => {
    await apiCall("POST", `llms/v1/students/${student_id}/enrollments`, {
      post_id: course_id,
    });
    // Store selected credit type as user meta if provided
    if (credit_type) {
      try {
        await apiCall("POST", `wp/v2/users/${student_id}`, {
          meta: {
            [`_llms_enrollment_credit_type_${course_id}`]: credit_type,
          },
        });
      } catch (e) {
        // Non-fatal — enrollment still succeeded
      }
    }
    const creditMsg = credit_type ? ` with ${credit_type.replace(/_/g, " ").toUpperCase()} credits` : "";
    return {
      content: [{ type: "text", text: `Student ${student_id} enrolled in course ${course_id}${creditMsg}.` }],
    };
  }
);

// ── Tool: cme_report ─────────────────────────────────────────────────────────

server.tool(
  "cme_report",
  "Generate a CME credit report for CME office submissions. Returns all credits awarded, with attestation and evaluation dates, filterable by date range, credit type, and course.",
  {
    start_date: z.string().optional().describe("Start date (YYYY-MM-DD)"),
    end_date: z.string().optional().describe("End date (YYYY-MM-DD)"),
    credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]).optional().describe("Filter by credit type"),
    course_id: z.number().optional().describe("Filter by course ID"),
  },
  async ({ start_date, end_date, credit_type, course_id }) => {
    const params = new URLSearchParams();
    if (start_date) params.set("start_date", start_date);
    if (end_date) params.set("end_date", end_date);
    if (credit_type) params.set("credit_type", credit_type);
    if (course_id) params.set("course_id", String(course_id));
    const qs = params.toString() ? `?${params}` : "";
    const report = await apiCall("GET", `llms/v1/mobile-app/cme/report${qs}`);

    // Format a readable summary
    const lines = [`CME Credit Report — generated ${report.generated_date}`];
    if (report.filters?.start_date || report.filters?.end_date) {
      lines.push(`Date range: ${report.filters.start_date || "beginning"} to ${report.filters.end_date || "now"}`);
    }
    lines.push(`Total records: ${report.total_records}`);
    lines.push("");

    if (report.summary?.length) {
      lines.push("── Summary by Credit Type ──");
      for (const s of report.summary) {
        lines.push(`  ${s.credit_type_label}: ${s.total_hours} hours across ${s.total_learners} learner(s)`);
      }
      lines.push("");
    }

    if (report.credits?.length) {
      lines.push("── Detail ──");
      for (const c of report.credits) {
        lines.push(`  ${c.user_name} (${c.user_email}) — ${c.credit_hours} ${c.credit_type_label} — ${c.course_title} — earned ${c.earned_date} — status: ${c.status}`);
      }
    }

    return {
      content: [{ type: "text", text: lines.join("\n") }],
    };
  }
);

// ── PowerPoint Parser Helpers ──────────────────────────────────────────────────

async function parsePptx(filePath) {
  const fileBuffer = await fs.readFile(filePath);
  const zip = await JSZip.loadAsync(fileBuffer);
  const parser = new xml2js.Parser({ explicitArray: false, ignoreAttrs: false });

  // Find all slide files in order
  const slideFiles = Object.keys(zip.files)
    .filter((f) => /^ppt\/slides\/slide\d+\.xml$/.test(f))
    .sort((a, b) => {
      const numA = parseInt(a.match(/slide(\d+)/)[1]);
      const numB = parseInt(b.match(/slide(\d+)/)[1]);
      return numA - numB;
    });

  const slides = [];

  for (const slideFile of slideFiles) {
    const slideNum = parseInt(slideFile.match(/slide(\d+)/)[1]);
    const xml = await zip.file(slideFile).async("text");
    const parsed = await parser.parseStringPromise(xml);

    const slide = { title: "", bullets: [], body: "", images: [] };

    // Extract text from shape tree
    const spTree = parsed?.["p:sld"]?.["p:cSld"]?.["p:spTree"];
    if (spTree) {
      const shapes = Array.isArray(spTree["p:sp"]) ? spTree["p:sp"] : spTree["p:sp"] ? [spTree["p:sp"]] : [];

      for (const shape of shapes) {
        const texts = extractTextsFromShape(shape);
        if (texts.length === 0) continue;

        // Check if this is likely a title (by placeholder type or first text block)
        const phType = shape?.["p:nvSpPr"]?.["p:nvPr"]?.["p:ph"]?.["$"]?.type;
        if (phType === "title" || phType === "ctrTitle") {
          slide.title = texts.join(" ");
        } else if (phType === "subTitle") {
          slide.body = texts.join("\n");
        } else if (texts.length > 1) {
          slide.bullets.push(...texts);
        } else if (!slide.title && texts[0].length < 100) {
          slide.title = texts[0];
        } else {
          slide.bullets.push(...texts);
        }
      }

      // Check for images (pictures)
      const pics = Array.isArray(spTree["p:pic"]) ? spTree["p:pic"] : spTree["p:pic"] ? [spTree["p:pic"]] : [];
      for (const pic of pics) {
        const rId = pic?.["p:blipFill"]?.["a:blip"]?.["$"]?.["r:embed"];
        if (rId) slide.images.push(rId);
      }
    }

    // Get speaker notes
    const notesFile = `ppt/notesSlides/notesSlide${slideNum}.xml`;
    if (zip.file(notesFile)) {
      try {
        const notesXml = await zip.file(notesFile).async("text");
        const notesParsed = await parser.parseStringPromise(notesXml);
        const notesSpTree = notesParsed?.["p:notes"]?.["p:cSld"]?.["p:spTree"];
        if (notesSpTree) {
          const noteShapes = Array.isArray(notesSpTree["p:sp"]) ? notesSpTree["p:sp"] : notesSpTree["p:sp"] ? [notesSpTree["p:sp"]] : [];
          const noteTexts = [];
          for (const shape of noteShapes) {
            const phType = shape?.["p:nvSpPr"]?.["p:nvPr"]?.["p:ph"]?.["$"]?.type;
            if (phType === "body") {
              noteTexts.push(...extractTextsFromShape(shape));
            }
          }
          slide.script = noteTexts.join("\n").trim();
        }
      } catch (_) {}
    }

    // If no title was found, use first bullet as title
    if (!slide.title && slide.bullets.length > 0) {
      slide.title = slide.bullets.shift();
    }

    slides.push(slide);
  }

  return slides;
}

function extractTextsFromShape(shape) {
  const texts = [];
  const txBody = shape?.["p:txBody"];
  if (!txBody) return texts;

  const paragraphs = Array.isArray(txBody["a:p"]) ? txBody["a:p"] : txBody["a:p"] ? [txBody["a:p"]] : [];

  for (const para of paragraphs) {
    const runs = Array.isArray(para["a:r"]) ? para["a:r"] : para["a:r"] ? [para["a:r"]] : [];
    const lineTexts = [];
    for (const run of runs) {
      const t = run["a:t"];
      if (t) {
        const text = typeof t === "string" ? t : t._ || "";
        if (text.trim()) lineTexts.push(text.trim());
      }
    }
    if (lineTexts.length > 0) {
      texts.push(lineTexts.join(" "));
    }
  }

  return texts;
}

function detectSlideLayout(slide) {
  if (slide.images.length > 0 && !slide.title) return "full_image";
  if (slide.images.length > 0) return "title_image";
  if (slide.bullets.length > 0) return "title_bullets";
  if (slide.body) return "title_body";
  return "title_bullets";
}

// ── Tool: import_powerpoint ───────────────────────────────────────────────────

server.tool(
  "import_powerpoint",
  "Import a PowerPoint (.pptx) file to create a course with slides. Extracts slide text, bullet points, and speaker notes (as narration scripts). Optionally splits into multiple lessons by a slide-per-lesson count.",
  {
    file_path: z.string().describe("Absolute path to the .pptx file"),
    course_title: z.string().optional().describe("Course title (defaults to filename)"),
    slides_per_lesson: z.number().optional().describe("Number of slides per lesson (default: all slides in one lesson)"),
    section_title: z.string().optional().describe("Section title (default: 'Module 1')"),
    status: z.enum(["publish", "draft"]).optional().describe("Course status (default: draft)"),
    cme: z.object({
      credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]),
      credit_hours: z.number(),
      disclosure_text: z.string().optional(),
      learning_objectives: z.array(z.string()).optional(),
      faculty_name: z.string().optional(),
      accreditation_statement: z.string().optional(),
    }).optional().describe("Optional CME configuration — will auto-prepend disclosure/objectives slides"),
  },
  async ({ file_path, course_title, slides_per_lesson, section_title, status = "draft", cme }) => {
    // 1. Parse the PowerPoint
    let rawSlides;
    try {
      rawSlides = await parsePptx(file_path);
    } catch (err) {
      return {
        content: [{ type: "text", text: `Failed to parse PowerPoint: ${err.message}` }],
      };
    }

    if (rawSlides.length === 0) {
      return {
        content: [{ type: "text", text: "No slides found in the PowerPoint file." }],
      };
    }

    // Derive course title from filename if not provided
    if (!course_title) {
      const parts = file_path.replace(/\\/g, "/").split("/");
      course_title = parts[parts.length - 1].replace(/\.pptx$/i, "").replace(/[-_]/g, " ");
    }

    // Convert raw slides to our slide format
    const convertedSlides = rawSlides.map((s) => {
      const slide = {
        title: s.title || "Untitled Slide",
        layout: detectSlideLayout(s),
      };
      if (s.bullets.length > 0) slide.bullets = s.bullets;
      if (s.body) slide.body = s.body;
      if (s.script) slide.script = s.script;
      return slide;
    });

    // Build CME prefix slides
    const cmePrefix = [];
    if (cme) {
      const disclosureBullets = [];
      if (cme.faculty_name) disclosureBullets.push(`Faculty: ${cme.faculty_name}`);
      disclosureBullets.push(cme.disclosure_text || "The faculty for this activity have no relevant financial relationships with ineligible companies to disclose.");
      if (cme.accreditation_statement) disclosureBullets.push(cme.accreditation_statement);
      disclosureBullets.push(`Credit: ${cme.credit_hours} ${cme.credit_type.replace(/_/g, " ").toUpperCase()} hour(s)`);

      cmePrefix.push({
        title: "Disclosures",
        layout: "title_bullets",
        bullets: disclosureBullets,
        background_color: "#1a237e",
        script: "Before we begin, please review the following disclosure information as required by accreditation standards.",
      });

      if (cme.learning_objectives && cme.learning_objectives.length > 0) {
        cmePrefix.push({
          title: "Learning Objectives",
          layout: "title_bullets",
          bullets: cme.learning_objectives,
          background_color: "#0d47a1",
          script: "At the conclusion of this activity, participants should be able to achieve the following objectives.",
        });
      }
    }

    // Split into lessons
    const perLesson = slides_per_lesson || convertedSlides.length;
    const lessonGroups = [];
    for (let i = 0; i < convertedSlides.length; i += perLesson) {
      lessonGroups.push(convertedSlides.slice(i, i + perLesson));
    }

    const result = { course: null, sections: [], slide_summary: { total_pptx_slides: rawSlides.length, lessons: lessonGroups.length }, errors: [] };

    // 2. Create course
    try {
      const course = await apiCall("POST", "llms/v1/courses", { title: course_title, status });
      result.course = { id: course.id, title: course_title };
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to create course: ${err.message}` }] };
    }

    const courseId = result.course.id;

    // 3. Create section
    let sectionId;
    try {
      const section = await apiCall("POST", "llms/v1/sections", {
        title: section_title || "Module 1",
        parent_id: courseId,
        order: 1,
      });
      sectionId = section.id;
    } catch (err) {
      result.errors.push(`Section: ${err.message}`);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }

    // 4. Create lessons with slides
    for (let li = 0; li < lessonGroups.length; li++) {
      const group = lessonGroups[li];
      const lessonTitle = lessonGroups.length === 1
        ? course_title
        : `${course_title} - Part ${li + 1}`;

      const lessonResult = { title: lessonTitle, id: null, slide_count: 0 };

      try {
        const lesson = await apiCall("POST", "llms/v1/lessons", {
          title: lessonTitle,
          parent_id: sectionId,
          order: li + 1,
        });
        lessonResult.id = lesson.id;

        // Prepend CME slides + lesson slides
        const finalSlides = [...cmePrefix, ...group];
        await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/slides`, { slides: finalSlides });
        lessonResult.slide_count = finalSlides.length;
      } catch (err) {
        result.errors.push(`Lesson "${lessonTitle}": ${err.message}`);
      }

      if (!result.sections[0]) result.sections[0] = { title: section_title || "Module 1", id: sectionId, lessons: [] };
      result.sections[0].lessons.push(lessonResult);
    }

    // 5. Configure CME if specified
    if (cme) {
      try {
        const cmeCredits = cme.credits && cme.credits.length > 0
          ? cme.credits
          : (cme.credit_type ? [{ credit_type: cme.credit_type, credit_hours: cme.credit_hours }] : []);
        await apiCall("POST", `wp/v2/courses/${courseId}`, {
          meta: {
            _llms_cme_enabled: "yes",
            _llms_cme_credits: JSON.stringify(cmeCredits),
            _llms_cme_credit_type: cmeCredits[0]?.credit_type || cme.credit_type,
            _llms_cme_credit_hours: String(cmeCredits[0]?.credit_hours || cme.credit_hours),
            _llms_cme_attestation_required: "yes",
            _llms_cme_evaluation_required: "yes",
          },
        });
        result.cme = {
          status: "configured",
          credits: buildCreditSummaryLines(cmeCredits),
        };
      } catch (err) {
        result.errors.push(`CME config: ${err.message}`);
      }
    }

    return {
      content: [{
        type: "text",
        text: JSON.stringify(result, null, 2),
      }],
    };
  }
);

// ── Tool: export_powerpoint ────────────────────────────────────────────────────

server.tool(
  "export_powerpoint",
  "Export a LifterLMS course as a PowerPoint (.pptx) file. Each lesson's slides become PowerPoint slides with speaker notes from narration scripts. If a lesson has no slides, its HTML content is placed as text on a single slide.",
  {
    course_id: z.number().describe("Course ID to export"),
    output_path: z.string().describe("Absolute path for the output .pptx file"),
    include_quizzes: z.boolean().optional().describe("Include quiz questions as slides (default: false)"),
  },
  async ({ course_id, output_path, include_quizzes = false }) => {
    // 1. Fetch course
    let course;
    try {
      course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to fetch course: ${err.message}` }] };
    }

    const courseTitle = course.title?.rendered || course.title || `Course ${course_id}`;

    // 2. Fetch sections
    let sections = [];
    try {
      const raw = await apiCall("GET", `llms/v1/sections?parent_id=${course_id}&per_page=50`);
      sections = Array.isArray(raw) ? raw : [];
    } catch (_) {}

    // 3. Fetch lessons per section
    const lessonsMap = {};
    for (const sec of sections) {
      try {
        const raw = await apiCall("GET", `llms/v1/lessons?parent_id=${sec.id}&per_page=100`);
        lessonsMap[sec.id] = Array.isArray(raw) ? raw : [];
      } catch (_) {
        lessonsMap[sec.id] = [];
      }
    }

    // 4. Build the PowerPoint
    const pptx = new PptxGenJS();
    pptx.title = courseTitle;
    pptx.subject = `Exported from LifterLMS (Course #${course_id})`;
    pptx.layout = "LAYOUT_WIDE";

    // Color palette
    const COLORS = {
      darkBlue: "1a237e",
      blue: "0d47a1",
      white: "FFFFFF",
      lightGray: "F5F5F5",
      darkText: "212121",
      subtitleText: "616161",
    };

    // Title slide
    const titleSlide = pptx.addSlide();
    titleSlide.background = { color: COLORS.darkBlue };
    titleSlide.addText(courseTitle, {
      x: 0.8, y: 1.5, w: "85%", h: 1.5,
      fontSize: 36, fontFace: "Calibri", color: COLORS.white, bold: true,
    });
    if (course.content?.rendered) {
      // Strip HTML tags for subtitle
      const desc = course.content.rendered.replace(/<[^>]*>/g, "").trim().substring(0, 200);
      if (desc) {
        titleSlide.addText(desc, {
          x: 0.8, y: 3.2, w: "85%", h: 1,
          fontSize: 16, fontFace: "Calibri", color: COLORS.white, italic: true,
        });
      }
    }

    let totalSlides = 1;
    let lessonsExported = 0;

    // 5. Process each section and lesson
    for (const sec of sections) {
      const sectionTitle = sec.title?.rendered || sec.title || "Section";

      // Section divider slide
      const secSlide = pptx.addSlide();
      secSlide.background = { color: COLORS.blue };
      secSlide.addText(sectionTitle, {
        x: 0.8, y: 2.0, w: "85%", h: 1.5,
        fontSize: 32, fontFace: "Calibri", color: COLORS.white, bold: true,
      });
      totalSlides++;

      const lessons = lessonsMap[sec.id] || [];
      for (const lesson of lessons) {
        const lessonTitle = lesson.title?.rendered || lesson.title || "Lesson";

        // Try to fetch slides for this lesson
        let lessonSlides = [];
        try {
          const slideData = await apiCall("GET", `llms/v1/mobile-app/lesson/${lesson.id}/slides`);
          if (slideData.has_slides && Array.isArray(slideData.slides)) {
            lessonSlides = slideData.slides;
          }
        } catch (_) {}

        if (lessonSlides.length > 0) {
          // Render each slide
          for (const s of lessonSlides) {
            const slide = pptx.addSlide();
            const bgHex = (s.background_color || "#FFFFFF").replace("#", "");
            slide.background = { color: bgHex };

            const isLight = isLightHex(bgHex);
            const textColor = isLight ? COLORS.darkText : COLORS.white;
            const subColor = isLight ? COLORS.subtitleText : "CCCCCC";

            switch (s.layout) {
              case "full_image":
                if (s.image_url) {
                  slide.addImage({ path: s.image_url, x: 0, y: 0, w: "100%", h: "100%" });
                }
                if (s.title) {
                  slide.addText(s.title, {
                    x: 0.5, y: 4.2, w: "90%", h: 0.8,
                    fontSize: 24, fontFace: "Calibri", color: COLORS.white, bold: true,
                    shadow: { type: "outer", blur: 6, offset: 2, color: "000000", opacity: 0.6 },
                  });
                }
                break;

              case "title_image":
                slide.addText(s.title || "", {
                  x: 0.8, y: 0.4, w: "85%", h: 0.8,
                  fontSize: 28, fontFace: "Calibri", color: textColor, bold: true,
                });
                if (s.image_url) {
                  slide.addImage({ path: s.image_url, x: 1.5, y: 1.5, w: 7, h: 4, sizing: { type: "contain" } });
                }
                break;

              case "title_body":
                slide.addText(s.title || "", {
                  x: 0.8, y: 0.4, w: "85%", h: 0.8,
                  fontSize: 28, fontFace: "Calibri", color: textColor, bold: true,
                });
                slide.addText(s.body || "", {
                  x: 0.8, y: 1.5, w: "85%", h: 3.5,
                  fontSize: 18, fontFace: "Calibri", color: subColor, lineSpacingMultiple: 1.3,
                });
                break;

              case "title_bullets":
              default:
                slide.addText(s.title || "", {
                  x: 0.8, y: 0.4, w: "85%", h: 0.8,
                  fontSize: 28, fontFace: "Calibri", color: textColor, bold: true,
                });
                if (s.bullets && s.bullets.length > 0) {
                  const bulletRows = s.bullets.map((b) => ({
                    text: b,
                    options: { fontSize: 18, color: subColor, bullet: { code: "2022" }, paraSpaceAfter: 8 },
                  }));
                  slide.addText(bulletRows, {
                    x: 0.8, y: 1.5, w: "85%", h: 3.8,
                    fontFace: "Calibri", lineSpacingMultiple: 1.2, valign: "top",
                  });
                }
                break;
            }

            // Add speaker notes from narration script
            if (s.script) {
              slide.addNotes(s.script);
            }

            totalSlides++;
          }
        } else {
          // No slides — create a single slide from lesson content
          const slide = pptx.addSlide();
          slide.background = { color: COLORS.lightGray };
          slide.addText(lessonTitle, {
            x: 0.8, y: 0.4, w: "85%", h: 0.8,
            fontSize: 28, fontFace: "Calibri", color: COLORS.darkText, bold: true,
          });

          // Strip HTML from content
          const content = (lesson.content?.rendered || "").replace(/<[^>]*>/g, "").trim();
          if (content) {
            slide.addText(content.substring(0, 1500), {
              x: 0.8, y: 1.5, w: "85%", h: 3.8,
              fontSize: 16, fontFace: "Calibri", color: COLORS.subtitleText,
              lineSpacingMultiple: 1.3, valign: "top",
            });
          }

          // Try to get lesson-level script for notes
          try {
            const scriptData = await apiCall("GET", `llms/v1/mobile-app/lesson/${lesson.id}/script`);
            if (scriptData.has_script && scriptData.script) {
              slide.addNotes(scriptData.script);
            }
          } catch (_) {}

          totalSlides++;
        }

        // Quiz slides
        if (include_quizzes && lesson.quiz_id) {
          try {
            const quiz = await apiCall("GET", `llms/v1/quizzes/${lesson.quiz_id}`);
            const quizTitle = quiz.title?.rendered || quiz.title || "Quiz";

            // Quiz title slide
            const qSlide = pptx.addSlide();
            qSlide.background = { color: "e65100" };
            qSlide.addText(quizTitle, {
              x: 0.8, y: 2.0, w: "85%", h: 1.5,
              fontSize: 32, fontFace: "Calibri", color: COLORS.white, bold: true,
            });
            if (quiz.passing_percent) {
              qSlide.addText(`Passing score: ${quiz.passing_percent}%`, {
                x: 0.8, y: 3.5, w: "85%", h: 0.6,
                fontSize: 18, fontFace: "Calibri", color: COLORS.white, italic: true,
              });
            }
            totalSlides++;

            // Individual question slides
            let questions = [];
            try {
              const raw = await apiCall("GET", `llms/v1/quizzes/${lesson.quiz_id}/questions?per_page=50`);
              questions = Array.isArray(raw) ? raw : [];
            } catch (_) {}

            for (let qi = 0; qi < questions.length; qi++) {
              const q = questions[qi];
              const questionSlide = pptx.addSlide();
              questionSlide.background = { color: "fff3e0" };

              questionSlide.addText(`Q${qi + 1}. ${q.title?.rendered || q.title || ""}`, {
                x: 0.8, y: 0.4, w: "85%", h: 1.0,
                fontSize: 22, fontFace: "Calibri", color: COLORS.darkText, bold: true,
              });

              // Show choices if available
              if (q.choices && q.choices.length > 0) {
                const choiceRows = q.choices.map((c, ci) => ({
                  text: `${String.fromCharCode(65 + ci)}. ${c.choice || c.title || ""}`,
                  options: { fontSize: 18, color: COLORS.subtitleText, paraSpaceAfter: 6 },
                }));
                questionSlide.addText(choiceRows, {
                  x: 1.0, y: 1.6, w: "80%", h: 3.5,
                  fontFace: "Calibri", valign: "top",
                });
              }

              // Put correct answer in speaker notes
              if (q.choices) {
                const correct = q.choices.filter((c) => c.correct).map((c) => c.choice || c.title).join(", ");
                if (correct) questionSlide.addNotes(`Correct answer: ${correct}`);
              }

              totalSlides++;
            }
          } catch (_) {}
        }

        lessonsExported++;
      }
    }

    // 6. Write file
    try {
      const dir = path.dirname(output_path);
      await fs.mkdir(dir, { recursive: true });
      const buffer = await pptx.write({ outputType: "nodebuffer" });
      await fs.writeFile(output_path, buffer);
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to write file: ${err.message}` }] };
    }

    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          status: "success",
          file: output_path,
          course: courseTitle,
          sections: sections.length,
          lessons_exported: lessonsExported,
          total_slides: totalSlides,
        }, null, 2),
      }],
    };
  }
);

// ── Image Helpers ──────────────────────────────────────────────────────────────

async function searchUnsplash(query, perPage = 1) {
  if (!UNSPLASH_ACCESS_KEY) return null;
  const url = `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=${perPage}&orientation=landscape`;
  const res = await fetch(url, {
    headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` },
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (!data.results || data.results.length === 0) return null;
  const photo = data.results[0];
  return {
    url: photo.urls.regular,
    download_url: photo.links.download_location,
    attribution: `Photo by ${photo.user.name} on Unsplash`,
    unsplash_id: photo.id,
  };
}

async function triggerUnsplashDownload(downloadLocationUrl) {
  if (!UNSPLASH_ACCESS_KEY || !downloadLocationUrl) return;
  try {
    await fetch(`${downloadLocationUrl}?client_id=${UNSPLASH_ACCESS_KEY}`);
  } catch (_) { /* best effort per Unsplash guidelines */ }
}

async function generateImageGemini(prompt) {
  if (!GEMINI_API_KEY) return null;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [
            {
              text: `Generate a professional, clean, medical-education-appropriate image for a CME course slide. The image should be: ${prompt}. Style: modern, clinical, professional photography or illustration style. No text overlays.`,
            },
          ],
        },
      ],
      generationConfig: {
        responseModalities: ["TEXT", "IMAGE"],
      },
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API ${res.status}: ${errText}`);
  }
  const data = await res.json();
  // Extract image data from Gemini response
  const candidates = data.candidates || [];
  for (const candidate of candidates) {
    const parts = candidate.content?.parts || [];
    for (const part of parts) {
      if (part.inlineData) {
        return {
          base64: part.inlineData.data,
          mimeType: part.inlineData.mimeType || "image/png",
        };
      }
    }
  }
  return null;
}

async function uploadToWordPressMedia(imageBuffer, filename, mimeType) {
  const url = `${SITE_URL}/wp-json/wp/v2/media`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: getAuthHeader(),
      "Content-Type": mimeType,
      "Content-Disposition": `attachment; filename="${filename}"`,
    },
    body: imageBuffer,
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`WP Media upload ${res.status}: ${errText}`);
  }
  const data = await res.json();
  return {
    id: data.id,
    url: data.source_url,
    title: data.title?.rendered || filename,
  };
}

async function fetchAndUploadUrl(imageUrl, filename) {
  const imgRes = await fetch(imageUrl);
  if (!imgRes.ok) throw new Error(`Failed to fetch image: ${imgRes.status}`);
  const buffer = Buffer.from(await imgRes.arrayBuffer());
  const contentType = imgRes.headers.get("content-type") || "image/jpeg";
  return uploadToWordPressMedia(buffer, filename, contentType);
}

async function setFeaturedImage(postType, postId, mediaId) {
  const url = `${SITE_URL}/wp-json/wp/v2/${postType}/${postId}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: getAuthHeader(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ featured_media: mediaId }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Set featured image failed ${res.status}: ${errText}`);
  }
  return await res.json();
}

async function prependImageToLessonContent(lessonId, imageUrl, altText) {
  // Get current lesson content
  const lesson = await apiCall("GET", `llms/v1/lessons/${lessonId}`);
  const currentContent = lesson.content?.rendered || lesson.content || "";
  const imgTag = `<figure class="wp-block-image size-large"><img src="${imageUrl}" alt="${altText}" style="width:100%;height:auto;border-radius:8px;margin-bottom:1.5em;" /></figure>\n`;
  const updatedContent = imgTag + currentContent;
  await apiCall("POST", `llms/v1/lessons/${lessonId}`, { content: updatedContent });
}

// ── Video Helpers ──────────────────────────────────────────────────────────────

async function generateVideoVeo(prompt, options = {}) {
  if (!GEMINI_API_KEY) return null;
  const model = options.fast ? "veo-3.1-fast-generate-preview" : "veo-3.1-generate-preview";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:predictLongRunning?key=${GEMINI_API_KEY}`;

  const parameters = {
    aspectRatio: options.aspectRatio || "16:9",
    durationSeconds: options.durationSeconds || 8,
    numberOfVideos: 1,
  };
  if (options.resolution) parameters.resolution = options.resolution;

  const body = {
    instances: [{ prompt }],
    parameters,
  };

  // Submit the long-running request
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Veo API ${res.status}: ${errText}`);
  }
  const operation = await res.json();
  const operationName = operation.name;
  if (!operationName) throw new Error("Veo API did not return an operation name");

  // Poll for completion
  const pollUrl = `https://generativelanguage.googleapis.com/v1beta/${operationName}?key=${GEMINI_API_KEY}`;
  const maxAttempts = 60; // 10 minutes max
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((r) => setTimeout(r, 10000)); // wait 10 seconds
    const pollRes = await fetch(pollUrl);
    if (!pollRes.ok) continue;
    const pollData = await pollRes.json();
    if (pollData.done) {
      const samples = pollData.response?.generateVideoResponse?.generatedSamples;
      if (!samples || samples.length === 0) throw new Error("Veo completed but returned no video");
      const videoUri = samples[0].video?.uri;
      if (!videoUri) throw new Error("Veo completed but no video URI found");
      return { uri: videoUri, model };
    }
  }
  throw new Error("Veo video generation timed out after 10 minutes");
}

async function downloadVeoVideo(videoUri) {
  // Veo returns a URI that requires the API key and follows redirects
  const separator = videoUri.includes("?") ? "&" : "?";
  const downloadUrl = `${videoUri}${separator}key=${GEMINI_API_KEY}`;
  const res = await fetch(downloadUrl, { redirect: "follow" });
  if (!res.ok) throw new Error(`Failed to download Veo video: ${res.status}`);
  const buffer = Buffer.from(await res.arrayBuffer());
  return { buffer, mimeType: res.headers.get("content-type") || "video/mp4" };
}

async function generateAndUploadVideo(prompt, sanitizedName, options = {}) {
  const veoResult = await generateVideoVeo(prompt, options);
  if (!veoResult) throw new Error("Video generation failed");

  const { buffer, mimeType } = await downloadVeoVideo(veoResult.uri);
  const ext = mimeType.includes("webm") ? "webm" : "mp4";
  const uploaded = await uploadToWordPressMedia(buffer, `${sanitizedName}.${ext}`, mimeType);
  return { wp_media_id: uploaded.id, url: uploaded.url, model: veoResult.model };
}

function buildVideoEmbed(videoUrl) {
  return `<figure class="wp-block-video"><video controls preload="metadata" style="width:100%;border-radius:8px;margin:1em 0;"><source src="${videoUrl}" type="video/mp4" />Your browser does not support the video tag.</video></figure>\n`;
}

async function generateAndAttachImage(prompt, sanitizedName, source, lessonId, postType = "lessons") {
  let uploaded = null;
  let usedSource = "";
  let attribution = null;

  // Try Unsplash first if auto or unsplash
  if (source === "unsplash" || source === "auto") {
    const stock = await searchUnsplash(prompt);
    if (stock) {
      uploaded = await fetchAndUploadUrl(stock.url, `${sanitizedName}.jpg`);
      await triggerUnsplashDownload(stock.download_url);
      usedSource = "unsplash";
      attribution = stock.attribution;
    }
  }

  // Fall back to Gemini
  if (!uploaded && (source === "gemini" || source === "auto") && GEMINI_API_KEY) {
    const generated = await generateImageGemini(prompt);
    if (generated) {
      const ext = generated.mimeType.includes("png") ? "png" : "jpg";
      const imageBuffer = Buffer.from(generated.base64, "base64");
      uploaded = await uploadToWordPressMedia(imageBuffer, `${sanitizedName}.${ext}`, generated.mimeType);
      usedSource = "gemini";
    }
  }

  if (!uploaded) return null;

  // Set as featured image
  try {
    await setFeaturedImage(postType, lessonId, uploaded.id);
  } catch (_) { /* some post types may not support featured images */ }

  // Prepend image into lesson HTML content
  try {
    await prependImageToLessonContent(lessonId, uploaded.url, prompt);
  } catch (_) { /* non-critical */ }

  return { wp_media_id: uploaded.id, url: uploaded.url, source: usedSource, attribution };
}

// ── Tool: generate_image ──────────────────────────────────────────────────────

server.tool(
  "generate_image",
  "Generate or find an image using AI (Gemini) or stock photos (Unsplash), upload to WordPress Media Library, and return the URL",
  {
    prompt: z.string().describe("Description of the image to generate or search for"),
    source: z
      .enum(["auto", "gemini", "unsplash"])
      .optional()
      .describe("Image source: 'gemini' for AI-generated, 'unsplash' for stock photos, 'auto' tries Unsplash first then Gemini (default: auto)"),
    upload_to_wp: z
      .boolean()
      .optional()
      .describe("Upload the image to WordPress Media Library (default: true)"),
  },
  async ({ prompt, source = "auto", upload_to_wp = true }) => {
    let result = null;
    let usedSource = "";
    const sanitizedName = prompt.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();

    if (source === "unsplash" || source === "auto") {
      const stock = await searchUnsplash(prompt);
      if (stock) {
        usedSource = "unsplash";
        if (upload_to_wp) {
          const uploaded = await fetchAndUploadUrl(stock.url, `${sanitizedName}.jpg`);
          await triggerUnsplashDownload(stock.download_url);
          result = {
            source: "unsplash",
            wp_media_id: uploaded.id,
            url: uploaded.url,
            attribution: stock.attribution,
          };
        } else {
          result = {
            source: "unsplash",
            url: stock.url,
            attribution: stock.attribution,
          };
        }
      }
    }

    if (!result && (source === "gemini" || source === "auto")) {
      if (!GEMINI_API_KEY) {
        throw new Error("GEMINI_API_KEY is not configured. Set it in .mcp.json env.");
      }
      const generated = await generateImageGemini(prompt);
      if (!generated) {
        throw new Error("Gemini did not return an image. Try a different prompt.");
      }
      usedSource = "gemini";
      const ext = generated.mimeType.includes("png") ? "png" : "jpg";
      const imageBuffer = Buffer.from(generated.base64, "base64");

      if (upload_to_wp) {
        const uploaded = await uploadToWordPressMedia(
          imageBuffer,
          `${sanitizedName}.${ext}`,
          generated.mimeType
        );
        result = {
          source: "gemini",
          wp_media_id: uploaded.id,
          url: uploaded.url,
        };
      } else {
        // Write to temp file and return path (less ideal)
        const tmpPath = path.join(process.cwd(), `${sanitizedName}.${ext}`);
        await fs.writeFile(tmpPath, imageBuffer);
        result = {
          source: "gemini",
          local_path: tmpPath,
          note: "Image saved locally. Set upload_to_wp=true to upload to WordPress.",
        };
      }
    }

    if (!result) {
      throw new Error(
        `No image found. ${!UNSPLASH_ACCESS_KEY ? "UNSPLASH_ACCESS_KEY not set. " : ""}${!GEMINI_API_KEY ? "GEMINI_API_KEY not set." : ""}`
      );
    }

    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  }
);

// ── Tool: add_image_to_lesson ─────────────────────────────────────────────────

server.tool(
  "add_image_to_lesson",
  "Generate or find an image and insert it at a specific position within a lesson's HTML content. Can target a heading number, paragraph number, or insert at the top/bottom. Also optionally sets as featured image.",
  {
    lesson_id: z.number().describe("Lesson ID to add the image to"),
    prompt: z.string().describe("Description of the image to generate (e.g., 'a child eating ice cream in a clinical waiting room')"),
    position: z
      .enum(["top", "bottom", "after_heading", "after_paragraph"])
      .optional()
      .describe("Where to insert the image (default: top)"),
    position_index: z
      .number()
      .optional()
      .describe("Which heading or paragraph to insert after (1-based). E.g., position='after_heading' + position_index=3 inserts after the 3rd heading."),
    caption: z.string().optional().describe("Optional caption to display below the image"),
    set_featured: z.boolean().optional().describe("Also set as the lesson's featured image (default: false)"),
    source: z
      .enum(["auto", "gemini", "unsplash"])
      .optional()
      .describe("Image source (default: auto)"),
  },
  async ({ lesson_id, prompt, position = "top", position_index = 1, caption, set_featured = false, source = "auto" }) => {
    // 1. Generate/find and upload the image
    const sanitizedName = prompt.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
    let uploaded = null;
    let usedSource = "";

    if (source === "unsplash" || source === "auto") {
      const stock = await searchUnsplash(prompt);
      if (stock) {
        uploaded = await fetchAndUploadUrl(stock.url, `${sanitizedName}.jpg`);
        await triggerUnsplashDownload(stock.download_url);
        usedSource = "unsplash";
      }
    }
    if (!uploaded && (source === "gemini" || source === "auto") && GEMINI_API_KEY) {
      const generated = await generateImageGemini(prompt);
      if (generated) {
        const ext = generated.mimeType.includes("png") ? "png" : "jpg";
        uploaded = await uploadToWordPressMedia(
          Buffer.from(generated.base64, "base64"),
          `${sanitizedName}.${ext}`,
          generated.mimeType
        );
        usedSource = "gemini";
      }
    }
    if (!uploaded) {
      throw new Error("Failed to generate or find an image. Check API keys.");
    }

    // 2. Build the image HTML
    const captionHtml = caption ? `<figcaption>${caption}</figcaption>` : "";
    const imgHtml = `<figure class="wp-block-image size-large"><img src="${uploaded.url}" alt="${prompt}" style="width:100%;height:auto;border-radius:8px;margin:1em 0;" />${captionHtml}</figure>\n`;

    // 3. Get current lesson content
    const lesson = await apiCall("GET", `llms/v1/lessons/${lesson_id}`);
    const currentContent = lesson.content?.rendered || lesson.content || "";

    // 4. Insert at the specified position
    let updatedContent;
    if (position === "top") {
      updatedContent = imgHtml + currentContent;
    } else if (position === "bottom") {
      updatedContent = currentContent + imgHtml;
    } else if (position === "after_heading") {
      // Find the Nth heading tag and insert after it
      let count = 0;
      const headingRegex = /<\/h[1-6]>/gi;
      let match;
      let insertPos = -1;
      while ((match = headingRegex.exec(currentContent)) !== null) {
        count++;
        if (count === position_index) {
          insertPos = match.index + match[0].length;
          break;
        }
      }
      if (insertPos === -1) {
        updatedContent = currentContent + imgHtml; // fallback to bottom
      } else {
        updatedContent = currentContent.slice(0, insertPos) + "\n" + imgHtml + currentContent.slice(insertPos);
      }
    } else if (position === "after_paragraph") {
      // Find the Nth </p> tag and insert after it
      let count = 0;
      const pRegex = /<\/p>/gi;
      let match;
      let insertPos = -1;
      while ((match = pRegex.exec(currentContent)) !== null) {
        count++;
        if (count === position_index) {
          insertPos = match.index + match[0].length;
          break;
        }
      }
      if (insertPos === -1) {
        updatedContent = currentContent + imgHtml;
      } else {
        updatedContent = currentContent.slice(0, insertPos) + "\n" + imgHtml + currentContent.slice(insertPos);
      }
    } else {
      updatedContent = imgHtml + currentContent;
    }

    // 5. Save updated content
    await apiCall("POST", `llms/v1/lessons/${lesson_id}`, { content: updatedContent });

    // 6. Optionally set as featured image
    if (set_featured) {
      try {
        await setFeaturedImage("lessons", lesson_id, uploaded.id);
      } catch (_) {}
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              lesson_id,
              lesson_title: lesson.title?.rendered || lesson.title,
              image_url: uploaded.url,
              wp_media_id: uploaded.id,
              source: usedSource,
              position: position === "after_heading" || position === "after_paragraph"
                ? `${position} #${position_index}`
                : position,
              caption: caption || null,
              set_as_featured: set_featured,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: generate_video ──────────────────────────────────────────────────────

server.tool(
  "generate_video",
  "Generate a video using Google Veo 3.1 AI, upload to WordPress Media Library, and return the URL. Video generation takes 30-120 seconds.",
  {
    prompt: z.string().describe("Description of the video to generate (e.g., 'a doctor explaining a diagnosis to a patient in a modern clinic')"),
    duration: z
      .number()
      .optional()
      .describe("Video duration in seconds: 4, 6, or 8 (default: 8)"),
    aspect_ratio: z
      .enum(["16:9", "9:16"])
      .optional()
      .describe("Aspect ratio: '16:9' landscape or '9:16' portrait (default: 16:9)"),
    resolution: z
      .enum(["720p", "1080p", "4k"])
      .optional()
      .describe("Video resolution (default: 720p). Note: 1080p and 4k require duration of 8 seconds"),
    fast: z
      .boolean()
      .optional()
      .describe("Use the fast model for quicker generation at potentially lower quality (default: false)"),
    upload_to_wp: z
      .boolean()
      .optional()
      .describe("Upload the video to WordPress Media Library (default: true)"),
  },
  async ({ prompt, duration = 8, aspect_ratio = "16:9", resolution, fast = false, upload_to_wp = true }) => {
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY is not configured.");

    const sanitizedName = prompt.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
    const options = { durationSeconds: duration, aspectRatio: aspect_ratio, fast };
    if (resolution) options.resolution = resolution;

    if (upload_to_wp) {
      const result = await generateAndUploadVideo(prompt, sanitizedName, options);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                source: "veo",
                model: result.model,
                wp_media_id: result.wp_media_id,
                url: result.url,
                duration,
                aspect_ratio,
              },
              null,
              2
            ),
          },
        ],
      };
    } else {
      const veoResult = await generateVideoVeo(prompt, options);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              { source: "veo", model: veoResult.model, download_uri: veoResult.uri, note: "Video available for 2 days at this URI." },
              null,
              2
            ),
          },
        ],
      };
    }
  }
);

// ── Tool: add_video_to_lesson ────────────────────────────────────────────────

server.tool(
  "add_video_to_lesson",
  "Generate a video using Veo 3.1 AI and insert it at a specific position within a lesson's HTML content. Also sets the lesson video_embed field. Video generation takes 30-120 seconds.",
  {
    lesson_id: z.number().describe("Lesson ID to add the video to"),
    prompt: z.string().describe("Description of the video to generate (e.g., 'a child interacting with a therapist during an ABA session')"),
    position: z
      .enum(["top", "bottom", "after_heading", "after_paragraph"])
      .optional()
      .describe("Where to insert the video (default: top)"),
    position_index: z
      .number()
      .optional()
      .describe("Which heading or paragraph to insert after (1-based)"),
    caption: z.string().optional().describe("Optional caption below the video"),
    duration: z
      .number()
      .optional()
      .describe("Video duration: 4, 6, or 8 seconds (default: 8)"),
    aspect_ratio: z
      .enum(["16:9", "9:16"])
      .optional()
      .describe("Aspect ratio (default: 16:9)"),
    fast: z
      .boolean()
      .optional()
      .describe("Use fast model for quicker generation (default: false)"),
  },
  async ({ lesson_id, prompt, position = "top", position_index = 1, caption, duration = 8, aspect_ratio = "16:9", fast = false }) => {
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY is not configured.");

    const sanitizedName = prompt.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();
    const options = { durationSeconds: duration, aspectRatio: aspect_ratio, fast };

    // 1. Generate and upload video
    const uploaded = await generateAndUploadVideo(prompt, sanitizedName, options);

    // 2. Build video HTML
    const captionHtml = caption ? `<figcaption>${caption}</figcaption>` : "";
    const videoHtml = `<figure class="wp-block-video"><video controls preload="metadata" style="width:100%;border-radius:8px;margin:1em 0;"><source src="${uploaded.url}" type="video/mp4" />Your browser does not support the video tag.</video>${captionHtml}</figure>\n`;

    // 3. Get current lesson content
    const lesson = await apiCall("GET", `llms/v1/lessons/${lesson_id}`);
    const currentContent = lesson.content?.rendered || lesson.content || "";

    // 4. Insert at specified position
    let updatedContent;
    if (position === "top") {
      updatedContent = videoHtml + currentContent;
    } else if (position === "bottom") {
      updatedContent = currentContent + videoHtml;
    } else if (position === "after_heading") {
      let count = 0;
      const headingRegex = /<\/h[1-6]>/gi;
      let match;
      let insertPos = -1;
      while ((match = headingRegex.exec(currentContent)) !== null) {
        count++;
        if (count === position_index) {
          insertPos = match.index + match[0].length;
          break;
        }
      }
      updatedContent = insertPos === -1
        ? currentContent + videoHtml
        : currentContent.slice(0, insertPos) + "\n" + videoHtml + currentContent.slice(insertPos);
    } else if (position === "after_paragraph") {
      let count = 0;
      const pRegex = /<\/p>/gi;
      let match;
      let insertPos = -1;
      while ((match = pRegex.exec(currentContent)) !== null) {
        count++;
        if (count === position_index) {
          insertPos = match.index + match[0].length;
          break;
        }
      }
      updatedContent = insertPos === -1
        ? currentContent + videoHtml
        : currentContent.slice(0, insertPos) + "\n" + videoHtml + currentContent.slice(insertPos);
    } else {
      updatedContent = videoHtml + currentContent;
    }

    // 5. Save updated content and set video_embed
    await apiCall("POST", `llms/v1/lessons/${lesson_id}`, {
      content: updatedContent,
      video_embed: uploaded.url,
    });

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              lesson_id,
              lesson_title: lesson.title?.rendered || lesson.title,
              video_url: uploaded.url,
              wp_media_id: uploaded.wp_media_id,
              model: uploaded.model,
              duration,
              position: position === "after_heading" || position === "after_paragraph"
                ? `${position} #${position_index}`
                : position,
              caption: caption || null,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: generate_course_videos ─────────────────────────────────────────────

server.tool(
  "generate_course_videos",
  "Auto-generate a short intro video for each lesson in a course using Veo 3.1. Uploads to WordPress and embeds in lesson content. WARNING: This is a long-running operation — each video takes 30-120 seconds to generate.",
  {
    course_id: z.number().describe("Course ID to generate videos for"),
    style_hint: z
      .string()
      .optional()
      .describe("Style guidance for video prompts (e.g., 'clinical setting, diverse medical professionals')"),
    duration: z
      .number()
      .optional()
      .describe("Duration per video in seconds: 4, 6, or 8 (default: 4 to keep generation fast)"),
    fast: z
      .boolean()
      .optional()
      .describe("Use fast model (default: true for batch operations)"),
  },
  async ({ course_id, style_hint = "", duration = 4, fast = true }) => {
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY is not configured.");

    const course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    const courseTitle = course.title?.rendered || course.title;
    const sections = await apiCall("GET", `llms/v1/sections?parent=${course_id}&per_page=50`);

    const results = [];
    const errors = [];

    for (const section of sections) {
      const lessons = await apiCall("GET", `llms/v1/lessons?parent=${section.id}&per_page=50`);

      for (const lesson of lessons) {
        const lessonTitle = lesson.title?.rendered || lesson.title;
        const videoPrompt = style_hint
          ? `Short educational intro clip for a medical CME lesson titled "${lessonTitle}". Style: ${style_hint}. Professional, clinical, no text overlays.`
          : `Short educational intro clip for a medical CME lesson titled "${lessonTitle}". Professional clinical setting, modern healthcare environment, no text overlays.`;
        const sanitizedName = lessonTitle.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();

        try {
          const uploaded = await generateAndUploadVideo(videoPrompt, sanitizedName, {
            durationSeconds: duration,
            aspectRatio: "16:9",
            fast,
          });

          // Prepend video to lesson content
          const videoHtml = buildVideoEmbed(uploaded.url);
          const currentContent = lesson.content?.rendered || lesson.content || "";
          await apiCall("POST", `llms/v1/lessons/${lesson.id}`, {
            content: videoHtml + currentContent,
            video_embed: uploaded.url,
          });

          results.push({
            lesson_id: lesson.id,
            lesson_title: lessonTitle,
            video_url: uploaded.url,
            wp_media_id: uploaded.wp_media_id,
          });
        } catch (err) {
          errors.push({
            lesson_id: lesson.id,
            lesson_title: lessonTitle,
            error: err.message,
          });
        }
      }
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              course_id,
              course_title: courseTitle,
              videos_generated: results.length,
              total_errors: errors.length,
              summary: `Generated ${results.length} lesson intro videos. Each was uploaded to WordPress and embedded at the top of the lesson content.`,
              results,
              errors: errors.length > 0 ? errors : undefined,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: upload_media ────────────────────────────────────────────────────────

server.tool(
  "upload_media",
  "Upload an image from a URL to the WordPress Media Library",
  {
    image_url: z.string().describe("URL of the image to upload"),
    filename: z.string().optional().describe("Filename for the uploaded image (default: derived from URL)"),
  },
  async ({ image_url, filename }) => {
    const fname = filename || image_url.split("/").pop().split("?")[0] || "image.jpg";
    const uploaded = await fetchAndUploadUrl(image_url, fname);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              wp_media_id: uploaded.id,
              url: uploaded.url,
              title: uploaded.title,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── Tool: generate_course_images ──────────────────────────────────────────────

server.tool(
  "generate_course_images",
  "Auto-generate images for an entire course. Generates a course featured image, then generates an image for each lesson — setting it as the lesson's featured image AND injecting it into the lesson HTML content. Uses Unsplash stock photos with Gemini AI fallback.",
  {
    course_id: z.number().describe("Course ID to generate images for"),
    source: z
      .enum(["auto", "gemini", "unsplash"])
      .optional()
      .describe("Image source preference (default: auto — tries Unsplash first, then Gemini)"),
    style_hint: z
      .string()
      .optional()
      .describe("Additional style guidance for image generation (e.g., 'medical illustrations', 'clinical photography', 'anatomical diagrams')"),
  },
  async ({ course_id, source = "auto", style_hint = "" }) => {
    const course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    const courseTitle = course.title?.rendered || course.title;
    const sections = await apiCall("GET", `llms/v1/sections?parent=${course_id}&per_page=50`);

    const results = [];
    const errors = [];

    // 1. Generate course-level featured image
    try {
      const coursePrompt = style_hint
        ? `${courseTitle}: ${style_hint}`
        : `${courseTitle}, professional medical education course cover image`;
      const courseSanitized = courseTitle.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();

      let courseUploaded = null;
      let courseSource = "";
      let courseAttribution = null;

      if (source === "unsplash" || source === "auto") {
        const stock = await searchUnsplash(coursePrompt);
        if (stock) {
          courseUploaded = await fetchAndUploadUrl(stock.url, `${courseSanitized}-cover.jpg`);
          await triggerUnsplashDownload(stock.download_url);
          courseSource = "unsplash";
          courseAttribution = stock.attribution;
        }
      }
      if (!courseUploaded && (source === "gemini" || source === "auto") && GEMINI_API_KEY) {
        const generated = await generateImageGemini(coursePrompt);
        if (generated) {
          const ext = generated.mimeType.includes("png") ? "png" : "jpg";
          courseUploaded = await uploadToWordPressMedia(
            Buffer.from(generated.base64, "base64"),
            `${courseSanitized}-cover.${ext}`,
            generated.mimeType
          );
          courseSource = "gemini";
        }
      }
      if (courseUploaded) {
        await setFeaturedImage("courses", course_id, courseUploaded.id);
        results.push({
          type: "course_cover",
          course_id,
          course_title: courseTitle,
          source: courseSource,
          wp_media_id: courseUploaded.id,
          url: courseUploaded.url,
          attribution: courseAttribution,
        });
      }
    } catch (err) {
      errors.push({ type: "course_cover", error: err.message });
    }

    // 2. Generate images for each lesson
    for (const section of sections) {
      const lessons = await apiCall("GET", `llms/v1/lessons?parent=${section.id}&per_page=50`);

      for (const lesson of lessons) {
        const lessonTitle = lesson.title?.rendered || lesson.title;
        const imagePrompt = style_hint
          ? `${lessonTitle}: ${style_hint}`
          : lessonTitle;
        const sanitizedName = lessonTitle.replace(/[^a-zA-Z0-9]/g, "-").substring(0, 50).toLowerCase();

        try {
          const imageResult = await generateAndAttachImage(
            imagePrompt, sanitizedName, source, lesson.id, "lessons"
          );

          if (imageResult) {
            results.push({
              type: "lesson_image",
              lesson_id: lesson.id,
              lesson_title: lessonTitle,
              source: imageResult.source,
              wp_media_id: imageResult.wp_media_id,
              url: imageResult.url,
              attribution: imageResult.attribution,
              attached: { featured_image: true, inline_content: true },
            });
          } else {
            errors.push({
              type: "lesson_image",
              lesson_id: lesson.id,
              lesson_title: lessonTitle,
              error: "No image source available",
            });
          }
        } catch (err) {
          errors.push({
            type: "lesson_image",
            lesson_id: lesson.id,
            lesson_title: lessonTitle,
            error: err.message,
          });
        }
      }
    }

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              course_id,
              course_title: courseTitle,
              total_images: results.length,
              total_errors: errors.length,
              summary: `Generated ${results.length} images (1 course cover + ${results.length - 1} lesson images). Each lesson image was set as featured image and injected into lesson HTML content.`,
              results,
              errors: errors.length > 0 ? errors : undefined,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ── PDF Helper ────────────────────────────────────────────────────────────────

function createPdf(outputPath) {
  const doc = new PDFDocument({ size: "LETTER", margins: { top: 60, bottom: 60, left: 60, right: 60 } });
  const stream = createWriteStream(outputPath);
  doc.pipe(stream);

  const helpers = {
    doc,
    stream,
    COLORS: { primary: "#1a237e", secondary: "#0d47a1", text: "#212121", muted: "#616161", accent: "#e65100" },

    title(text) {
      doc.fontSize(24).font("Helvetica-Bold").fillColor(helpers.COLORS.primary).text(text, { align: "left" });
      doc.moveDown(0.3);
      doc.moveTo(60, doc.y).lineTo(552, doc.y).strokeColor(helpers.COLORS.primary).lineWidth(2).stroke();
      doc.moveDown(0.8);
    },

    heading(text) {
      doc.fontSize(16).font("Helvetica-Bold").fillColor(helpers.COLORS.secondary).text(text);
      doc.moveDown(0.4);
    },

    subheading(text) {
      doc.fontSize(13).font("Helvetica-Bold").fillColor(helpers.COLORS.text).text(text);
      doc.moveDown(0.3);
    },

    body(text) {
      doc.fontSize(11).font("Helvetica").fillColor(helpers.COLORS.text).text(text, { lineGap: 3 });
      doc.moveDown(0.4);
    },

    muted(text) {
      doc.fontSize(10).font("Helvetica").fillColor(helpers.COLORS.muted).text(text, { lineGap: 2 });
      doc.moveDown(0.3);
    },

    bullet(text) {
      doc.fontSize(11).font("Helvetica").fillColor(helpers.COLORS.text)
        .text(`  •  ${text}`, { indent: 10, lineGap: 2 });
      doc.moveDown(0.15);
    },

    numberedItem(num, text) {
      doc.fontSize(11).font("Helvetica").fillColor(helpers.COLORS.text)
        .text(`${num}. ${text}`, { indent: 10, lineGap: 2 });
      doc.moveDown(0.15);
    },

    separator() {
      doc.moveDown(0.3);
      doc.moveTo(60, doc.y).lineTo(552, doc.y).strokeColor("#E0E0E0").lineWidth(0.5).stroke();
      doc.moveDown(0.5);
    },

    checkPage(needed = 100) {
      if (doc.y > 680 - needed) {
        doc.addPage();
      }
    },

    async finish() {
      doc.end();
      return new Promise((resolve, reject) => {
        stream.on("finish", resolve);
        stream.on("error", reject);
      });
    },
  };

  return helpers;
}

// ── Tool: export_pdf ──────────────────────────────────────────────────────────

server.tool(
  "export_pdf",
  "Export a LifterLMS course as a PDF document suitable for peer review. Includes all slides, narration scripts, quiz questions, and CME configuration.",
  {
    course_id: z.number().describe("Course ID to export"),
    output_path: z.string().describe("Absolute path for the output .pdf file"),
    include_quizzes: z.boolean().optional().describe("Include quiz questions (default: true)"),
    include_scripts: z.boolean().optional().describe("Include narration scripts (default: true)"),
  },
  async ({ course_id, output_path, include_quizzes = true, include_scripts = true }) => {
    // 1. Fetch course
    let course;
    try {
      course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to fetch course: ${err.message}` }] };
    }

    const courseTitle = course.title?.rendered || course.title || `Course ${course_id}`;
    const pdf = createPdf(output_path);

    // Title page
    pdf.doc.moveDown(3);
    pdf.doc.fontSize(32).font("Helvetica-Bold").fillColor(pdf.COLORS.primary).text(courseTitle, { align: "center" });
    pdf.doc.moveDown(1);

    const desc = (course.content?.rendered || "").replace(/<[^>]*>/g, "").trim();
    if (desc) {
      pdf.doc.fontSize(12).font("Helvetica").fillColor(pdf.COLORS.muted)
        .text(desc.substring(0, 500), { align: "center", width: 430, indent: 0 });
    }

    pdf.doc.moveDown(2);
    pdf.muted(`Course ID: ${course_id}`);
    pdf.muted(`Exported: ${new Date().toISOString().split("T")[0]}`);

    // CME config
    let cmeConfig = null;
    try {
      cmeConfig = await apiCall("GET", `llms/v1/mobile-app/cme/course/${course_id}`);
    } catch (_) {}

    if (cmeConfig?.enabled) {
      pdf.doc.moveDown(0.5);
      pdf.subheading("CME Accreditation");
      if (cmeConfig.credits?.length) {
        for (const c of cmeConfig.credits) {
          pdf.bullet(`${c.credit_hours} ${c.credit_type_label}${c.accrediting_institution ? ` (${c.accrediting_institution})` : ""}`);
        }
      } else {
        pdf.bullet(`${cmeConfig.credit_hours} ${cmeConfig.credit_type_label}`);
      }
      if (cmeConfig.disclosure_text) {
        pdf.doc.moveDown(0.3);
        pdf.muted(`Disclosure: ${cmeConfig.disclosure_text}`);
      }
    }

    // 2. Fetch sections & lessons
    let sections = [];
    try {
      const raw = await apiCall("GET", `llms/v1/sections?parent_id=${course_id}&per_page=50`);
      sections = Array.isArray(raw) ? raw : [];
    } catch (_) {}

    const lessonsMap = {};
    for (const sec of sections) {
      try {
        const raw = await apiCall("GET", `llms/v1/lessons?parent_id=${sec.id}&per_page=100`);
        lessonsMap[sec.id] = Array.isArray(raw) ? raw : [];
      } catch (_) {
        lessonsMap[sec.id] = [];
      }
    }

    // 3. Render each section
    let lessonCount = 0;
    for (let si = 0; si < sections.length; si++) {
      const sec = sections[si];
      const sectionTitle = sec.title?.rendered || sec.title || `Section ${si + 1}`;

      pdf.doc.addPage();
      pdf.title(`Section ${si + 1}: ${sectionTitle}`);

      const lessons = lessonsMap[sec.id] || [];
      for (let li = 0; li < lessons.length; li++) {
        const lesson = lessons[li];
        const lessonTitle = lesson.title?.rendered || lesson.title || `Lesson ${li + 1}`;
        lessonCount++;

        pdf.checkPage(120);
        pdf.heading(`${si + 1}.${li + 1}  ${lessonTitle}`);

        // Fetch slides
        let slides = [];
        try {
          const slideData = await apiCall("GET", `llms/v1/mobile-app/lesson/${lesson.id}/slides`);
          if (slideData.has_slides && Array.isArray(slideData.slides)) {
            slides = slideData.slides;
          }
        } catch (_) {}

        if (slides.length > 0) {
          for (let si2 = 0; si2 < slides.length; si2++) {
            const s = slides[si2];
            pdf.checkPage(80);
            pdf.subheading(`Slide ${si2 + 1}: ${s.title || "(untitled)"}`);

            if (s.body) {
              pdf.body(s.body);
            }
            if (s.bullets?.length) {
              for (const b of s.bullets) {
                pdf.bullet(b);
              }
              pdf.doc.moveDown(0.2);
            }
            if (include_scripts && s.script) {
              pdf.checkPage(60);
              pdf.doc.fontSize(10).font("Helvetica-Oblique").fillColor("#7B1FA2")
                .text("Narration:", { continued: false });
              pdf.doc.fontSize(10).font("Helvetica").fillColor(pdf.COLORS.muted)
                .text(s.script, { lineGap: 2 });
              pdf.doc.moveDown(0.3);
            }
          }
        } else {
          // No slides — use lesson content
          const content = (lesson.content?.rendered || "").replace(/<[^>]*>/g, "").trim();
          if (content) {
            pdf.body(content.substring(0, 2000));
          }
        }

        // Quiz
        if (include_quizzes && lesson.quiz_id) {
          try {
            const quiz = await apiCall("GET", `llms/v1/quizzes/${lesson.quiz_id}`);
            const quizTitle = quiz.title?.rendered || quiz.title || "Quiz";
            pdf.checkPage(80);
            pdf.subheading(`Quiz: ${quizTitle}`);
            if (quiz.passing_percent) {
              pdf.muted(`Passing score: ${quiz.passing_percent}%`);
            }

            let questions = [];
            try {
              const raw = await apiCall("GET", `llms/v1/quizzes/${lesson.quiz_id}/questions?per_page=50`);
              questions = Array.isArray(raw) ? raw : [];
            } catch (_) {}

            for (let qi = 0; qi < questions.length; qi++) {
              const q = questions[qi];
              const qText = (q.title?.rendered || q.title || "").replace(/<[^>]*>/g, "");
              pdf.checkPage(60);
              pdf.numberedItem(qi + 1, qText);

              if (q.choices && Array.isArray(q.choices)) {
                for (const ch of q.choices) {
                  const choiceText = (ch.choice?.rendered || ch.choice || "").replace(/<[^>]*>/g, "");
                  const marker = ch.correct ? "✓" : "○";
                  pdf.doc.fontSize(10).font("Helvetica").fillColor(ch.correct ? "#2E7D32" : pdf.COLORS.muted)
                    .text(`      ${marker}  ${choiceText}`, { lineGap: 1 });
                }
                pdf.doc.moveDown(0.2);
              }
            }
          } catch (_) {}
        }

        pdf.separator();
      }
    }

    // Finish
    await pdf.finish();

    return {
      content: [{ type: "text", text: `PDF exported: ${output_path}\n${sections.length} sections, ${lessonCount} lessons.` }],
    };
  }
);

// ── Tool: generate_course_planning_doc ────────────────────────────────────────

server.tool(
  "generate_course_planning_doc",
  "Generate a CME Course Planning Document (PDF) for submission to a CME office. Includes needs assessment, learning objectives, target audience, content outline, faculty disclosures, assessment strategy, and evaluation plan — all extracted from the course data.",
  {
    course_id: z.number().describe("Course ID"),
    output_path: z.string().describe("Absolute path for the output .pdf file"),
    needs_assessment: z.string().optional().describe("Practice gap / needs assessment text. If omitted, auto-generated from course content."),
    faculty_name: z.string().optional().describe("Faculty/author name"),
    faculty_degrees: z.string().optional().describe("Faculty degrees (e.g., 'MD, PhD')"),
    faculty_institution: z.string().optional().describe("Faculty institution"),
    faculty_disclosures: z.string().optional().describe("COI disclosures (e.g., 'No relevant financial relationships')"),
  },
  async ({ course_id, output_path, needs_assessment, faculty_name, faculty_degrees, faculty_institution, faculty_disclosures }) => {
    // 1. Fetch course
    let course;
    try {
      course = await apiCall("GET", `llms/v1/courses/${course_id}`);
    } catch (err) {
      return { content: [{ type: "text", text: `Failed to fetch course: ${err.message}` }] };
    }

    const courseTitle = course.title?.rendered || course.title || `Course ${course_id}`;
    const courseDesc = (course.content?.rendered || "").replace(/<[^>]*>/g, "").trim();

    // 2. Fetch CME config
    let cmeConfig = null;
    try {
      cmeConfig = await apiCall("GET", `llms/v1/mobile-app/cme/course/${course_id}`);
    } catch (_) {}

    // 3. Fetch sections & lessons for content outline
    let sections = [];
    try {
      const raw = await apiCall("GET", `llms/v1/sections?parent_id=${course_id}&per_page=50`);
      sections = Array.isArray(raw) ? raw : [];
    } catch (_) {}

    const lessonsMap = {};
    let totalLessons = 0;
    let totalQuizzes = 0;
    for (const sec of sections) {
      try {
        const raw = await apiCall("GET", `llms/v1/lessons?parent_id=${sec.id}&per_page=100`);
        const lessons = Array.isArray(raw) ? raw : [];
        lessonsMap[sec.id] = lessons;
        totalLessons += lessons.length;
        totalQuizzes += lessons.filter((l) => l.quiz_id).length;
      } catch (_) {
        lessonsMap[sec.id] = [];
      }
    }

    // 4. Extract learning objectives from first lesson's disclosure slide
    let objectives = [];
    if (sections.length > 0) {
      const firstSectionLessons = lessonsMap[sections[0].id] || [];
      for (const lesson of firstSectionLessons) {
        try {
          const slideData = await apiCall("GET", `llms/v1/mobile-app/lesson/${lesson.id}/slides`);
          if (slideData.has_slides && Array.isArray(slideData.slides)) {
            for (const s of slideData.slides) {
              if (s.title && /objective/i.test(s.title) && s.bullets?.length) {
                objectives = s.bullets;
                break;
              }
            }
          }
        } catch (_) {}
        if (objectives.length > 0) break;
      }
    }

    // 5. Build the PDF
    const pdf = createPdf(output_path);

    // Header
    pdf.doc.moveDown(2);
    pdf.doc.fontSize(14).font("Helvetica-Bold").fillColor(pdf.COLORS.primary)
      .text("CME ACTIVITY PLANNING DOCUMENT", { align: "center" });
    pdf.doc.moveDown(0.3);
    pdf.doc.fontSize(10).font("Helvetica").fillColor(pdf.COLORS.muted)
      .text("For Submission to CME/CNE Accreditation Office", { align: "center" });
    pdf.doc.moveDown(1.5);

    pdf.doc.fontSize(22).font("Helvetica-Bold").fillColor(pdf.COLORS.primary).text(courseTitle, { align: "center" });
    pdf.doc.moveDown(0.5);
    pdf.muted(`Date: ${new Date().toISOString().split("T")[0]}     |     Course ID: ${course_id}     |     Format: Enduring Material (Online, Self-Paced)`);
    pdf.doc.moveDown(0.5);

    // Credit info
    if (cmeConfig?.enabled) {
      pdf.heading("Credit Designation");
      if (cmeConfig.credits?.length) {
        for (const c of cmeConfig.credits) {
          pdf.bullet(`${c.credit_hours} ${c.credit_type_label}${c.accrediting_institution ? ` — ${c.accrediting_institution}` : ""}`);
        }
      } else if (cmeConfig.credit_type) {
        pdf.bullet(`${cmeConfig.credit_hours} ${cmeConfig.credit_type_label}`);
      }
      pdf.doc.moveDown(0.3);
    }

    pdf.separator();

    // Section 1: Activity Overview
    pdf.heading("1. Activity Overview");
    pdf.body(`Title: ${courseTitle}`);
    pdf.body("Format: Enduring material — self-paced online education delivered via mobile app (iOS/Android), TV app (Apple TV, Fire TV, Google TV), and web.");
    if (courseDesc) {
      pdf.body(`Description: ${courseDesc.substring(0, 600)}`);
    }
    pdf.body(`Content: ${sections.length} sections, ${totalLessons} lessons, ${totalQuizzes} assessments`);
    if (course.length?.rendered || course.length) {
      const len = course.length?.rendered || course.length;
      pdf.body(`Estimated duration: ${len}`);
    }
    pdf.separator();

    // Section 2: Target Audience
    pdf.heading("2. Target Audience");
    if (cmeConfig?.credits?.length) {
      const audiences = [];
      for (const c of cmeConfig.credits) {
        const typeMap = {
          ama_pra_1: "Physicians (MD/DO), Physician Assistants",
          ancc: "Registered Nurses, Nurse Practitioners, Clinical Nurse Specialists",
          acpe: "Pharmacists, Pharmacy Technicians",
          aafp: "Family Physicians",
          aapa: "Physician Assistants",
        };
        audiences.push(typeMap[c.credit_type] || "Healthcare professionals");
      }
      pdf.body([...new Set(audiences)].join("; "));
    } else {
      pdf.body("Healthcare professionals seeking continuing education credits.");
    }
    pdf.separator();

    // Section 3: Needs Assessment
    pdf.heading("3. Needs Assessment / Practice Gap");
    if (needs_assessment) {
      pdf.body(needs_assessment);
    } else {
      pdf.body(`This activity addresses a knowledge and practice gap in ${courseTitle.toLowerCase().replace(/^(a |an |the )/i, "")}. Evidence suggests that healthcare providers require updated education in this area to improve patient outcomes and align with current evidence-based guidelines.`);
      pdf.doc.moveDown(0.2);
      pdf.muted("[Note: Replace with specific literature references, practice data, or quality improvement data supporting the educational need.]");
    }
    pdf.separator();

    // Section 4: Learning Objectives
    pdf.checkPage(120);
    pdf.heading("4. Learning Objectives");
    pdf.body("Upon completion of this activity, participants should be able to:");
    if (objectives.length > 0) {
      for (let i = 0; i < objectives.length; i++) {
        pdf.numberedItem(i + 1, objectives[i]);
      }
    } else {
      pdf.muted("[Learning objectives will be extracted from course content. Ensure objectives are measurable and map to identified practice gaps.]");
    }
    pdf.separator();

    // Section 5: Content Outline
    pdf.checkPage(100);
    pdf.heading("5. Content Outline");
    for (let si = 0; si < sections.length; si++) {
      const sec = sections[si];
      const secTitle = sec.title?.rendered || sec.title || `Section ${si + 1}`;
      pdf.subheading(`Section ${si + 1}: ${secTitle}`);

      const lessons = lessonsMap[sec.id] || [];
      for (let li = 0; li < lessons.length; li++) {
        const lesson = lessons[li];
        const lessonTitle = lesson.title?.rendered || lesson.title || `Lesson ${li + 1}`;
        const quizNote = lesson.quiz_id ? " [Assessment]" : "";
        pdf.bullet(`${si + 1}.${li + 1}  ${lessonTitle}${quizNote}`);
      }
      pdf.doc.moveDown(0.2);
    }
    pdf.separator();

    // Section 6: Faculty & Disclosures
    pdf.checkPage(120);
    pdf.heading("6. Faculty Information & Disclosures");
    if (faculty_name) {
      pdf.body(`Faculty: ${faculty_name}${faculty_degrees ? `, ${faculty_degrees}` : ""}`);
      if (faculty_institution) pdf.body(`Institution: ${faculty_institution}`);
      pdf.doc.moveDown(0.3);
    }
    pdf.subheading("Disclosure Statement");
    if (faculty_disclosures) {
      pdf.body(faculty_disclosures);
    } else if (cmeConfig?.disclosure_text) {
      pdf.body(cmeConfig.disclosure_text);
    } else {
      pdf.body("The faculty/author(s) have no relevant financial relationships with ineligible companies to disclose.");
    }
    pdf.separator();

    // Section 7: Assessment Strategy
    pdf.checkPage(100);
    pdf.heading("7. Assessment Strategy");
    pdf.body(`This activity includes ${totalQuizzes} knowledge-check assessment(s) embedded within the course modules.`);
    pdf.bullet("Post-lesson quizzes assess retention and comprehension of key concepts");
    if (cmeConfig?.attestation_required) {
      pdf.bullet("Learner attestation required prior to credit award");
    }
    if (cmeConfig?.evaluation_required) {
      pdf.bullet("Post-activity evaluation required prior to credit award");
    }
    pdf.body("Passing threshold: Learners must achieve the designated passing score on all assessments to receive credit.");
    pdf.separator();

    // Section 8: Evaluation Plan
    pdf.checkPage(120);
    pdf.heading("8. Evaluation Plan");
    pdf.body("All participants will complete a post-activity evaluation survey addressing:");
    pdf.bullet("Relevance of content to clinical practice (1-5 scale)");
    pdf.bullet("Achievement of stated learning objectives (1-5 scale)");
    pdf.bullet("Freedom from commercial bias (Yes/No)");
    pdf.bullet("Anticipated changes to practice (Yes/No with free-text follow-up)");
    pdf.bullet("Perceived barriers to implementing changes");
    pdf.bullet("Open-ended suggestions for future activities");
    pdf.doc.moveDown(0.3);
    pdf.body("Evaluation data will be aggregated and submitted to the accreditation office as part of outcomes reporting.");
    pdf.separator();

    // Section 9: Commercial Support
    pdf.checkPage(60);
    pdf.heading("9. Commercial Support");
    pdf.body("This activity does not receive any commercial support. There are no grants, sponsorships, or in-kind contributions from ineligible companies.");
    pdf.separator();

    // Section 10: Delivery Platforms
    pdf.checkPage(80);
    pdf.heading("10. Delivery Platforms");
    pdf.body("This enduring material is available on the following platforms:");
    pdf.bullet("iOS and Android mobile applications");
    pdf.bullet("Apple TV, Amazon Fire TV, and Google TV applications");
    pdf.bullet("Web browser via the LifterLMS learning management system");
    pdf.doc.moveDown(0.3);
    pdf.body("All platforms provide identical content delivery with slide-based lessons, optional text-to-speech narration, and embedded assessments.");

    // Footer
    pdf.doc.moveDown(2);
    pdf.doc.fontSize(9).font("Helvetica").fillColor(pdf.COLORS.muted)
      .text("This document was generated by the LifterLMS CME Platform. All course content, structure, and accreditation configuration are derived from the live course data.", { align: "center" });

    await pdf.finish();

    return {
      content: [{ type: "text", text: `Course planning document generated: ${output_path}\n\nIncludes: Activity overview, target audience, needs assessment, ${objectives.length} learning objectives, content outline (${sections.length} sections / ${totalLessons} lessons), faculty disclosures, assessment strategy, evaluation plan, commercial support statement, and delivery platforms.` }],
    };
  }
);

// ── Utilities ──────────────────────────────────────────────────────────────────

function isLightHex(hex) {
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.5;
}

// ── Start Server ───────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
