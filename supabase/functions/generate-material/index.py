import os
import textwrap
from typing import Any, Dict

import requests

# API config
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "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")
GROQ_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

def generate_material(course_title: str, material_title: str, lesson_title: str) -> str:
    """Generate educational material using Groq's API."""
    
    prompt = f"""As an expert educator, create comprehensive educational material for the following:
    Course: {course_title}
    Lesson: {lesson_title}
    Material Topic: {material_title}

    Please provide:
    1. A detailed explanation of the topic
    2. Key concepts and definitions
    3. Examples and applications
    4. Practice questions or exercises
    5. Additional resources or references

    Format the content in a clear, structured way that's easy for students to understand."""

    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {GROQ_API_KEY}"
        }

        data = {
            "model": GROQ_MODEL,
            "messages": [
                {
                    "role": "system",
                    "content": "You are an expert educator creating high-quality educational content."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }

        response = requests.post(GROQ_API_URL, headers=headers, json=data)

        if response.status_code != 200:
            raise Exception(f"API request failed with status {response.status_code}: {response.text}")

        result = response.json()
        content = result['choices'][0]['message']['content'].strip()
        
        # Format the content with proper wrapping
        formatted_content = textwrap.fill(content, width=100, replace_whitespace=False)
        
        return formatted_content

    except Exception as e:
        print(f"Error generating material: {str(e)}")
        raise

def main(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handle the Edge Function request."""
    try:
        # Get request body
        body = event.get("body", {})
        
        # Extract parameters
        course_title = body.get("course_title")
        material_title = body.get("material_title")
        lesson_title = body.get("lesson_title")

        if not all([course_title, material_title, lesson_title]):
            return {
                "statusCode": 400,
                "body": {"error": "Missing required parameters"}
            }

        # Generate material
        content = generate_material(course_title, material_title, lesson_title)

        return {
            "statusCode": 200,
            "body": {
                "content": content
            }
        }

    except Exception as e:
        print(f"Error in main function: {str(e)}")
        return {
            "statusCode": 500,
            "body": {"error": str(e)}
        } 