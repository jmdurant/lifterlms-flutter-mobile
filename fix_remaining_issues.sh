#!/bin/bash

echo "Fixing remaining LifterLMS migration issues..."

# Fix RxBool to bool conversions in views
echo "Fixing RxBool to bool conversions..."
find lib/app/view -name "*.dart" -exec sed -i 's/\.value as bool/.value/g' {} \;
find lib/app/view -name "*.dart" -exec sed -i 's/RxBool\s\+\(\w\+\)\s*=/bool \1=/g' {} \;

# Fix getUserInfo references
echo "Fixing getUserInfo references..."
find lib/app/view -name "*.dart" -exec sed -i 's/parser\.getUserInfo()/Get.find<SharedPreferencesManager>().getString("user_data")/g' {} \;
find lib/app/view -name "*.dart" -exec sed -i 's/\.getUserInfo()/\.getString("user_data")/g' {} \;

# Fix can_retake references
echo "Fixing can_retake references..."
find lib/app/view -name "*.dart" -exec sed -i 's/value\.course\.value?.can_retake/false \/\/ TODO: can_retake/g' {} \;

# Fix price null safety
echo "Fixing price null safety..."
find lib/app/view -name "*.dart" -exec sed -i 's/value\.course\.value?.price!/\(value.course.value?.price ?? 0\)/g' {} \;

# Fix sections empty check
echo "Fixing sections empty check..."
find lib/app/view -name "*.dart" -exec sed -i 's/!value\.course\.value?.sections!\.isEmpty/\(value.course.value?.sections?.isNotEmpty ?? false\)/g' {} \;

# Fix instructor references that are still broken
echo "Fixing remaining instructor references..."
find lib/app/view -name "*.dart" -exec sed -i 's/value\.course\.instructor\[/\/\/ TODO: Fix - value.course.instructor\[/g' {} \;

echo "Done! Check compilation errors with: flutter build apk --debug"