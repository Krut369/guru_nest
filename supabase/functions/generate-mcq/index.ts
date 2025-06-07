// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// API config
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") || "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";
const GROQ_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { course_title, quiz_title, description } = await req.json();

    const prompt = `
Generate 5 multiple-choice questions (MCQs) for a quiz.
Course Title: ${course_title}
Quiz Title: ${quiz_title}
Description: ${description}

IMPORTANT: Each question MUST have EXACTLY 4 options (A, B, C, D) and ONE correct answer.

For each question:
1. Write a clear and concise question
2. Provide EXACTLY 4 options labeled A, B, C, and D
3. Specify which option is correct (A, B, C, or D)
4. Include a brief explanation for why the correct answer is right

Format each question as a JSON object with this EXACT structure (NO comments, NO markdown, NO trailing commas):
{
    "question": "The question text",
    "options": [
        { "text": "Option A text", "is_correct": false },
        { "text": "Option B text", "is_correct": false },
        { "text": "Option C text", "is_correct": false },
        { "text": "Option D text", "is_correct": false }
    ],
    "explanation": "Brief explanation of the correct answer"
}

Return ONLY a JSON array of these objects. Do NOT include any markdown, code blocks, or comments.`;

    const response = await fetch(GROQ_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          {
            role: "system",
            content: "You are an expert educator creating high-quality multiple choice questions. Each question MUST have exactly 4 options and one correct answer. Always return ONLY valid JSON. Do NOT include markdown, code blocks, or comments."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 2000
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Groq API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    let content = data.choices?.[0]?.message?.content ?? "";

    if (!content.trim()) {
      throw new Error("Groq returned empty content. Check your API key and prompt.");
    }

    let questions = [];

    // Clean response by removing code blocks, comments, and trimming
    let cleaned = content
      .replace(/```json|```/g, "") // Remove code block markers
      .replace(/\n\s*\/\/.*$/gm, "") // Remove JS-style comments
      .replace(/\n\s*#.*$/gm, "") // Remove Python-style comments
      .replace(/\r?\n/g, " ") // Flatten newlines
      .replace(/\s+/g, " ") // Collapse whitespace
      .trim();

    try {
      // Try parsing cleaned content directly
      const parsed = JSON.parse(cleaned);

      if (Array.isArray(parsed)) {
        questions = parsed;
      } else if (parsed.questions && Array.isArray(parsed.questions)) {
        questions = parsed.questions;
      } else {
        throw new Error("Parsed JSON is not an array or object with 'questions' array");
      }

      // Validate each question has exactly 4 options and one correct answer
      questions = questions.map((q, index) => {
        if (!Array.isArray(q.options) || q.options.length !== 4) {
          throw new Error(`Question ${index + 1} must have exactly 4 options`);
        }
        // Ensure exactly one option is marked as correct
        const correctOptions = q.options.filter(opt => opt.is_correct);
        if (correctOptions.length !== 1) {
          throw new Error(`Question ${index + 1} must have exactly one correct option`);
        }
        return {
          question: q.question,
          options: q.options,
          explanation: q.explanation
        };
      });

    } catch (e) {
      // Fallback: extract first JSON array substring from cleaned content
      const match = cleaned.match(/\[[\s\S]*\]/);
      if (match) {
        questions = JSON.parse(match[0]);
      } else {
        throw new Error("No valid JSON array found in AI response");
      }
    }

    return new Response(JSON.stringify({ questions }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
