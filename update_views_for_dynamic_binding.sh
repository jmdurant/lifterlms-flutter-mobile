#!/bin/bash

# Script to update all view files to use dynamic controller resolution
# This enables switching between LearnPress and LifterLMS at runtime

echo "Starting view updates for dynamic controller binding..."

# Function to update a specific controller reference in views
update_controller_references() {
    local controller_name=$1
    local resolver_method=$2
    
    echo "Updating references for ${controller_name}Controller..."
    
    # Find all dart files in view directory that reference this controller
    find lib/app/view -name "*.dart" -type f | while read -r file; do
        if grep -q "${controller_name}Controller" "$file"; then
            echo "  Processing: $file"
            
            # Backup the file
            cp "$file" "${file}.backup"
            
            # Check if dynamic binding import is already present
            if ! grep -q "lms_dynamic_binding.dart" "$file"; then
                # Add import after the last import statement
                sed -i '/^import /{ 
                    $a\import '\''package:flutter_app/app/backend/binding/lms_dynamic_binding.dart'\'';
                }' "$file"
            fi
            
            # Update Get.find<Controller> patterns
            sed -i "s/Get\.find<${controller_name}Controller>()/LMSControllerResolver.get${controller_name}Controller()/g" "$file"
            
            # Update direct controller imports from lifterlms
            sed -i "s|import 'package:flutter_app/app/controller/lifterlms/${controller_name,,}_controller.dart';|// Dynamic controller resolution - no direct import needed|g" "$file"
            
            # Update direct controller imports from standard location
            sed -i "s|import 'package:flutter_app/app/controller/${controller_name,,}_controller.dart';|// Dynamic controller resolution - no direct import needed|g" "$file"
            
            # Update GetView<Controller> declarations to use dynamic
            sed -i "s/GetView<${controller_name}Controller>/GetView<dynamic>/g" "$file"
            
            # Update final/var Controller declarations
            sed -i "s/final ${controller_name}Controller /final /g" "$file"
            sed -i "s/${controller_name}Controller /var /g" "$file"
        fi
    done
}

# List of controllers to update
CONTROLLERS=(
    "Home"
    "Courses"
    "CourseDetail"
    "Learning"
    "Wishlist"
    "MyCourses"
    "Login"
    "Register"
    "SearchCourse"
    "InstructorDetail"
    "Profile"
    "MyProfile"
    "Notification"
    "Payment"
    "Review"
    "FinishLearning"
    "ForgotPassword"
    "Settings"
    "Tabs"
    "Splash"
)

# Process each controller
for controller in "${CONTROLLERS[@]}"; do
    update_controller_references "$controller" "$controller"
done

echo ""
echo "View update complete!"
echo ""
echo "Manual steps required:"
echo "1. Review the updated view files for any custom logic"
echo "2. Test both LearnPress and LifterLMS modes"
echo "3. Handle any type-specific method calls that may need adjustment"
echo ""
echo "To switch platforms at runtime, use:"
echo "  LMSConfig.switchPlatform('learnpress');"
echo "  LMSDynamicBinding.reloadControllers();"
echo ""
echo "Or:"
echo "  LMSConfig.switchPlatform('lifterlms');"
echo "  LMSDynamicBinding.reloadControllers();"