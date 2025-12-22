# Next Feature Development

Ready to prioritize the next feature.

## Active Focus

None currently set.

---

## Available Feature Ideas

See the following documents for potential next features:
- `FeedbackIdeas.md` - User-requested features from beta tester survey
- `PremiumVersionIdeas.md` - Planned paid features (token doublers, commander tools, etc.)
- `commanderWidgets.md` - Commander Mode system design

---

## Process for Adding New Utility Types (Reference Checklist)

When implementing new utility types, follow the comprehensive checklist that was used for Krenko and Cathar's Crusade implementations. This checklist covers:

1. Data Model creation with Hive annotations
2. Constants and type IDs
3. Hive setup and registration
4. Provider implementation with CRUD methods
5. Main app initialization
6. Widget card UI (use TokenCard as reference for artwork)
7. Widget definition and database integration
8. ContentScreen integration for display and reordering
9. Widget selection screen integration
10. Code generation
11. Testing checklist including artwork display modes

Refer to git history for Cathar's Crusade and Krenko implementations as examples.
