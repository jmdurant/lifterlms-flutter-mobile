import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ── Configuration ──────────────────────────────────────────────────────────────

const SITE_URL = process.env.LIFTERLMS_SITE_URL || "";
const CONSUMER_KEY = process.env.LIFTERLMS_CONSUMER_KEY || "";
const CONSUMER_SECRET = process.env.LIFTERLMS_CONSUMER_SECRET || "";

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
    content: z.string().optional().describe("Lesson content (HTML)"),
    excerpt: z.string().optional().describe("Lesson excerpt"),
    order: z.number().optional().describe("Position order within the section"),
    video_embed: z.string().optional().describe("Video embed URL"),
    audio_embed: z.string().optional().describe("Audio embed URL"),
    script: z.string().optional().describe("Narration script / text to read for this lesson"),
  },
  async ({ title, parent_id, content, excerpt, order, video_embed, audio_embed, script }) => {
    const body = { title, parent_id };
    if (content) body.content = content;
    if (excerpt) body.excerpt = excerpt;
    if (order !== undefined) body.order = order;
    if (video_embed) body.video_embed = video_embed;
    if (audio_embed) body.audio_embed = audio_embed;

    const lesson = await apiCall("POST", "llms/v1/lessons", body);

    // Save script as post meta
    if (script) {
      try {
        await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/script`, { script });
      } catch (_) {
        // Fallback: save via WP post meta
        try {
          await apiCall("POST", `wp/v2/lessons/${lesson.id}`, {
            meta: { _llms_lesson_script: script },
          });
        } catch (_) {}
      }
    }

    return {
      content: [{
        type: "text",
        text: `Lesson created: ID ${lesson.id}, title "${title}" in section ${parent_id}` +
          (script ? ` (with narration script, ${script.length} chars)` : ""),
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

// ── Tool: configure_cme ────────────────────────────────────────────────────────

server.tool(
  "configure_cme",
  "Configure CME (Continuing Medical Education) credits for a course",
  {
    course_id: z.number().describe("Course ID"),
    credit_type: z.enum([
      "ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom",
    ]).describe("CME credit type"),
    credit_hours: z.number().describe("Number of credit hours"),
    expiration_months: z.number().optional().describe("Months until credits expire (0 = never)"),
    attestation_required: z.boolean().optional().describe("Require attestation before awarding credits"),
    attestation_text: z.string().optional().describe("Attestation statement text"),
    evaluation_required: z.boolean().optional().describe("Require post-activity evaluation"),
    disclosure_text: z.string().optional().describe("Faculty disclosure/conflict of interest text"),
  },
  async ({ course_id, credit_type, credit_hours, expiration_months = 0, attestation_required = true, attestation_text, evaluation_required = true, disclosure_text }) => {
    // Set course meta via WordPress REST API
    // These are stored as post meta on the course
    const metaUpdates = {
      _llms_cme_enabled: "yes",
      _llms_cme_credit_type: credit_type,
      _llms_cme_credit_hours: String(credit_hours),
      _llms_cme_expiration_months: String(expiration_months),
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

    const creditLabels = {
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

    return {
      content: [{
        type: "text",
        text: `CME configured for course ${course_id}:\n` +
          `  Credit type: ${creditLabels[credit_type]}\n` +
          `  Hours: ${credit_hours}\n` +
          `  Expiration: ${expiration_months > 0 ? expiration_months + " months" : "Never"}\n` +
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
        content: z.string().optional().describe("Lesson content (HTML)"),
        script: z.string().optional().describe("Narration script / text to read for this lesson"),
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
      credit_type: z.enum(["ama_pra_1", "ama_pra_2", "ancc", "acpe", "aafp", "aapa", "moc", "ce", "ceu", "custom"]),
      credit_hours: z.number(),
      expiration_months: z.number().optional(),
      attestation_required: z.boolean().optional(),
      evaluation_required: z.boolean().optional(),
      disclosure_text: z.string().optional(),
    }).optional().describe("Optional CME credit configuration"),
  },
  async ({ title, description, status = "draft", sections, cme }) => {
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

          // Save narration script if provided
          if (les.script) {
            try {
              await apiCall("POST", `llms/v1/mobile-app/lesson/${lesson.id}/script`, { script: les.script });
              lessonResult.has_script = true;
            } catch (_) {
              try {
                await apiCall("POST", `wp/v2/lessons/${lesson.id}`, {
                  meta: { _llms_lesson_script: les.script },
                });
                lessonResult.has_script = true;
              } catch (_) {
                result.errors.push(`Script for "${les.title}": failed to save`);
              }
            }
          }
        } catch (err) {
          result.errors.push(`Lesson "${les.title}": ${err.message}`);
          sectionResult.lessons.push(lessonResult);
          continue;
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
        const metaUpdates = {
          _llms_cme_enabled: "yes",
          _llms_cme_credit_type: cme.credit_type,
          _llms_cme_credit_hours: String(cme.credit_hours),
          _llms_cme_expiration_months: String(cme.expiration_months || 0),
          _llms_cme_attestation_required: (cme.attestation_required !== false) ? "yes" : "no",
          _llms_cme_evaluation_required: (cme.evaluation_required !== false) ? "yes" : "no",
        };
        if (cme.disclosure_text) metaUpdates._llms_cme_disclosure_text = cme.disclosure_text;

        await apiCall("POST", `wp/v2/courses/${courseId}`, { meta: metaUpdates });
        result.cme = "configured";
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
  "Enroll a student in a course",
  {
    student_id: z.number().describe("Student/user ID"),
    course_id: z.number().describe("Course ID"),
  },
  async ({ student_id, course_id }) => {
    await apiCall("POST", `llms/v1/students/${student_id}/enrollments`, {
      post_id: course_id,
    });
    return {
      content: [{ type: "text", text: `Student ${student_id} enrolled in course ${course_id}.` }],
    };
  }
);

// ── Start Server ───────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
