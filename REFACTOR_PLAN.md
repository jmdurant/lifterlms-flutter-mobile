# LifterLMS Flutter Mobile - Refactoring Plan

## Phase 1: Critical Security Fixes
- [ ] **1A** Remove plaintext password storage in login_controller.dart (use flutter_secure_storage)
- [ ] **1B** Remove all sensitive print() statements (JWT payloads, tokens, login responses)
- [ ] **1C** Remove purchase-code.txt from repo, add to .gitignore
- [ ] **1D** Migrate token storage from SharedPreferences to flutter_secure_storage

**Order**: 1A first, then 1B/1C/1D in parallel

## Phase 2: State Management Consolidation (GetX only)
- [ ] **2A** Create GetX replacements for 4 MobX stores (SessionStore, CourseStore, WishlistStore, LearningQuizStore)
- [ ] **2B** Update 20+ view files: replace locator<>/WatchingWidget/Provider.of with Get.find/GetView
- [ ] **2C** Update main.dart: remove MultiProvider, MobX imports, setupLocator()
- [ ] **2D** Remove packages from pubspec.yaml (mobx, flutter_mobx, provider, get_it, watch_it, bloc, flutter_bloc, mobx_codegen, build_runner)

**Order**: 2A -> 2B (parallelizable across files) -> 2C -> 2D

## Phase 3: Remove Dead Code Layers
- [ ] **3A** Audit which parse files are still actively used (splash_controller, settings_controller)
- [ ] **3B** Migrate remaining parse consumers to direct API/LMSService calls
- [ ] **3C** Delete all 22 parse files, clean up init.dart registrations
- [ ] **3D** Delete 14 empty (0-byte) old controller stubs

**Order**: 3A -> 3B -> 3C/3D in parallel

## Phase 4: Code Quality
- [ ] **4A** Fix ResponseV2 circular reference bug (toJson assigns map to itself)
- [ ] **4B** Remove/replace 488 print() statements with proper logger utility
- [ ] **4C** Break up learning_controller.dart (1,278 lines) into controller + mixins
- [ ] **4D** Break up course_detail_controller.dart (1,029 lines) into controller + mixins
- [ ] **4E** Fix API cache-buster URL bug (double ? in query string)

**Order**: 4A/4B/4E in parallel, 4C/4D in parallel

## Phase 5: Branding/Config Cleanup
- [ ] **5A** Fix iOS Info.plist (Eduma Flutter -> LifterLMS, duplicate UIBackgroundModes, microphone description)
- [ ] **5B** Android package rename (com.edumaflutter -> TBD, update build.gradle, manifest, kotlin path)
- [ ] **5C** Update pubspec.yaml name (flutter_app -> lifterlms_mobile) + all import paths

**Order**: 5A/5B in parallel, 5C separate (high blast radius)

## Phase 6: Test Infrastructure
- [ ] **6A** Replace broken widget_test.dart with smoke test
- [ ] **6B** Create unit tests for models and controllers
- [ ] **6C** Add test helpers and mock data
- [ ] **6D** Add CI test script

**Order**: All parallel

---

## Summary

| Phase | Files Deleted | Files Modified | Files Created | Risk |
|-------|--------------|----------------|---------------|------|
| 1     | 1            | ~5             | 1             | Medium |
| 2     | ~10          | ~25            | 3-4           | High |
| 3     | ~36          | ~3             | 0             | Medium |
| 4     | 0            | ~35            | 2-3           | Low-Med |
| 5     | 0            | ~5 (+213 for 5C) | 0           | Low-Med |
| 6     | 0            | 1              | 4-5           | None |
