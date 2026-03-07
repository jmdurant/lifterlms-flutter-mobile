# LifterLMS Flutter Mobile - Refactoring Plan

## Phase 1: Critical Security Fixes -- COMPLETE
- [x] **1A** Remove plaintext password storage in login_controller.dart (use flutter_secure_storage)
- [x] **1B** Remove all sensitive print() statements (JWT payloads, tokens, login responses)
- [x] **1C** Remove purchase-code.txt from repo, add to .gitignore
- [x] **1D** Migrate token storage from SharedPreferences to flutter_secure_storage

## Phase 2: State Management Consolidation (GetX only) -- COMPLETE
- [x] **2A** Create GetX replacements for 4 MobX stores (SessionStore, CourseStore, WishlistStore, LearningQuizStore)
- [x] **2B** Update 25+ view files: replace locator<>/WatchingWidget/Provider.of with Get.find/StatelessWidget
- [x] **2C** Update main.dart: remove MultiProvider, MobX imports, setupLocator()
- [x] **2D** Remove packages from pubspec.yaml (mobx, flutter_mobx, provider, get_it, watch_it, bloc, flutter_bloc, mobx_codegen, build_runner)

## Phase 3: Remove Dead Code Layers -- COMPLETE
- [x] **3A** Audit which parse files are still actively used
- [x] **3B** Migrate remaining parse consumers (splash, settings, notification, social_login) to direct API calls
- [x] **3C** Delete all 22 parse files, clean up init.dart registrations
- [x] **3D** Delete 16 empty (0-byte) old controller stubs

## Phase 4: Code Quality -- COMPLETE (4C/4D deferred)
- [x] **4A** Fix ResponseV2 circular reference bug (toJson assigns map to itself)
- [x] **4B** Remove 502 print() statements, create AppLogger utility
- [ ] **4C** Break up learning_controller.dart — DEFERRED (low ROI, risk of regressions)
- [ ] **4D** Break up course_detail_controller.dart — DEFERRED (low ROI, risk of regressions)
- [x] **4E** Fix API cache-buster URL bug (double ? in query string)

## Phase 5: Branding/Config Cleanup -- COMPLETE (5C deferred)
- [x] **5A** Fix iOS Info.plist (Eduma Flutter -> LifterLMS, duplicate UIBackgroundModes, microphone description)
- [x] **5B** Android label (flutter_app -> LifterLMS in AndroidManifest.xml)
- [ ] **5C** Update pubspec.yaml name (flutter_app -> lifterlms_mobile) — DEFERRED (touches 200+ imports, high risk)

## Phase 6: Test Infrastructure -- TODO
- [ ] **6A** Replace broken widget_test.dart with smoke test
- [ ] **6B** Create unit tests for models and controllers
- [ ] **6C** Add test helpers and mock data
- [ ] **6D** Add CI test script

---

## Results

| Phase | Files Changed | Lines Removed | Lines Added | Packages Removed |
|-------|--------------|---------------|-------------|-----------------|
| 1     | 12           | 120           | 163         | 0               |
| 2     | 41           | 725           | 124         | 7               |
| 3+4   | 77           | 2,318         | 353         | 0               |
| 5     | 3            | 11            | 7           | 0               |
| **Total** | **133**  | **~3,174**    | **~647**    | **7**           |

Net reduction: ~2,500 lines of code and 48 files removed.
