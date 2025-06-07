import json
import os
from typing import Any, Dict

import requests

# API config
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "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")
GROQ_MODEL = "llama2-70b-4096"  # Updated to use a valid Groq model

def generate_mcq(course_title: str, quiz_title: str, description: str) -> list:
    """Generate multiple choice questions using Groq's API."""
    
    prompt = f"""As an expert educator, create multiple choice questions for the following:
    Course: {course_title}
    Quiz Title: {quiz_title}
    Description: {description}

    Please generate 5 high-quality multiple choice questions. For each question:
    1. Provide a clear and concise question
    2. Include 4 possible answers (A, B, C, D)
    3. Indicate the correct answer
    4. Provide a brief explanation for the correct answer

    Format each question as a JSON object with the following structure:
    {{
        "question": "The question text",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correct_option_index": 0,
        "explanation": "Explanation of the correct answer"
    }}

    Return the questions as a JSON array."""

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
                    "content": "You are an expert educator creating high-quality multiple choice questions. Always return valid JSON."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        }

        print("Making request to Groq API...")
        response = requests.post(GROQ_API_URL, headers=headers, json=data)
        print(f"Response status: {response.status_code}")
        print(f"Response body: {response.text}")

        if response.status_code != 200:
            error_msg = f"Groq API request failed with status {response.status_code}"
            try:
                error_data = response.json()
                error_msg += f": {json.dumps(error_data)}"
            except:
                error_msg += f": {response.text}"
            raise Exception(error_msg)

        result = response.json()
        content = result['choices'][0]['message']['content'].strip()
        
        # Parse the JSON response
        try:
            questions = json.loads(content)
            if not isinstance(questions, list):
                raise ValueError("Response is not a list of questions")
            return questions
        except json.JSONDecodeError as e:
            print(f"Failed to parse JSON response: {content}")
            raise Exception(f"Invalid JSON response from Groq API: {str(e)}")

    except Exception as e:
        print(f"Error generating MCQs: {str(e)}")
        raise

def main(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handle the Edge Function request."""
    try:
        # Get request body
        body = event.get("body", {})
        
        # Extract parameters
        course_title = body.get("course_title")
        quiz_title = body.get("quiz_title")
        description = body.get("description", "")

        if not all([course_title, quiz_title]):
            return {
                "statusCode": 400,
                "body": {"error": "Missing required parameters"}
            }

        # Generate MCQs
        questions = generate_mcq(course_title, quiz_title, description)

        return {
            "statusCode": 200,
            "body": {
                "questions": questions
            }
        }

    except Exception as e:
        print(f"Error in main function: {str(e)}")
        return {
            "statusCode": 500,
            "body": {"error": str(e)}
        } 