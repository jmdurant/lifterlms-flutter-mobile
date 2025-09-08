#!/bin/bash

# Script to update all parser files for LifterLMS compatibility
# This adds platform-specific logic to each parser

echo "Starting parser updates for LifterLMS compatibility..."

# List of parser files to update
PARSER_FILES=(
    "lib/app/backend/parse/home_parse.dart"
    "lib/app/backend/parse/courses_parse.dart"
    "lib/app/backend/parse/course_detail_parse.dart"
    "lib/app/backend/parse/learning_parse.dart"
    "lib/app/backend/parse/wishlist_parse.dart"
    "lib/app/backend/parse/my_courses_parse.dart"
    "lib/app/backend/parse/login_parse.dart"
    "lib/app/backend/parse/register_parse.dart"
    "lib/app/backend/parse/search_course_parse.dart"
    "lib/app/backend/parse/instructor_detail_parse.dart"
    "lib/app/backend/parse/profile_parse.dart"
    "lib/app/backend/parse/my_profile_parse.dart"
    "lib/app/backend/parse/finish-learning_parse.dart"
    "lib/app/backend/parse/forgot_password_parse.dart"
    "lib/app/backend/parse/notification_parse.dart"
    "lib/app/backend/parse/payment_parse.dart"
    "lib/app/backend/parse/review_parse.dart"
    "lib/app/backend/parse/settings_parse.dart"
    "lib/app/backend/parse/social_login_parse.dart"
    "lib/app/backend/parse/splash_parse.dart"
    "lib/app/backend/parse/tabs_parse.dart"
)

# Function to add LifterLMS support to a parser file
add_lifterlms_support() {
    local file=$1
    local filename=$(basename "$file" .dart)
    
    echo "Processing $filename..."
    
    # Check if file already has LifterLMS imports
    if grep -q "LMSConfig" "$file"; then
        echo "  ✓ Already has LMS platform support"
        return
    fi
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Add import for LMS config at the beginning of the file (after package declaration)
    sed -i '1a\import '\''package:flutter_app/app/config/lms_config.dart'\'';' "$file"
    
    echo "  ✓ Added LMS config import"
    
    # TODO: Add platform-specific API call logic to each parser
    # This would require analyzing each parser's methods and adding conditional logic
    # For now, we're just adding the import
}

# Process each parser file
for file in "${PARSER_FILES[@]}"; do
    if [ -f "$file" ]; then
        add_lifterlms_support "$file"
    else
        echo "Warning: $file not found"
    fi
done

echo ""
echo "Parser update complete!"
echo ""
echo "Next steps:"
echo "1. Review each parser file to add platform-specific API logic"
echo "2. Update API endpoints based on LMSConfig.isLearnPress flag"
echo "3. Test both LearnPress and LifterLMS modes"
echo ""
echo "Example pattern to use in parsers:"
echo "  if (LMSConfig.isLearnPress) {"
echo "    // LearnPress API call"
echo "    var response = await apiService.getPublic(AppConstants.courseUri);"
echo "  } else {"
echo "    // LifterLMS API call"
echo "    var response = await apiService.getPublic('/llms/v1/courses');"
echo "  }"