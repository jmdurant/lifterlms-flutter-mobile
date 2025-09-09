#!/bin/bash

# LifterLMS Mobile API Test Script
# Site: https://polite-tree.myliftersite.com/

# Set your credentials here
CONSUMER_KEY="your_consumer_key"
CONSUMER_SECRET="your_consumer_secret"
BASE_URL="https://polite-tree.myliftersite.com/wp-json/llms/v1"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Testing LifterLMS Mobile API Endpoints"
echo "======================================="

# Test 1: Get Quiz Data
echo -e "\n${GREEN}1. Testing Get Quiz (ID: 4810)${NC}"
curl -X GET "$BASE_URL/mobile-app/quiz/4810" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

# Test 2: Get Quiz Questions
echo -e "\n${GREEN}2. Testing Get Quiz Questions (ID: 4810)${NC}"
curl -X GET "$BASE_URL/mobile-app/quiz/4810/questions" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

# Test 3: Start Quiz Attempt
echo -e "\n${GREEN}3. Testing Start Quiz Attempt${NC}"
curl -X POST "$BASE_URL/mobile-app/quiz/4810/start" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"lesson_id": 4808}' \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

# Test 4: Get User Certificates
echo -e "\n${GREEN}4. Testing Get Certificates${NC}"
curl -X GET "$BASE_URL/mobile-app/certificates?page=1&limit=20" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

# Test 5: Get Course Sections
echo -e "\n${GREEN}5. Testing Get Course Sections (Course ID: 4800)${NC}"
curl -X GET "$BASE_URL/sections?course=4800" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

# Test 6: Get Lesson
echo -e "\n${GREEN}6. Testing Get Lesson (ID: 4808)${NC}"
curl -X GET "$BASE_URL/lessons/4808" \
  -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
  -H "Content-Type: application/json" \
  -w "\nHTTP Status: %{http_code}\n" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to parse JSON"

echo -e "\n${GREEN}Testing Complete!${NC}"