# Managing Health and Wellbeing

> Classification: Canonical user guide
> Audience: Users tracking personal wellness and care evidence
> Capability status: Current workspace; non-clinical
> Source authority: [Track and Wellness](../product/TRACK_AND_WELLNESS.md), Health runtime, and [Feature Catalog](../product/FEATURE_CATALOG.md)
> Last verified: 2026-08-11

LifeBoard organizes personal evidence; it does not diagnose, prescribe, interpret urgent symptoms, or replace a clinician. Contact appropriate professional or emergency services when needed.

## Connect Health by domain

Open Settings → Calendar & Health and request only useful domains:

- activity and walking distance;
- active and resting energy;
- hydration;
- nutrition and macros;
- body mass, body fat, waist, and resting heart rate;
- workouts;
- sleep;
- fasting context.

Activity, energy, sleep, and fasting context are read-only. Hydration, nutrition, body, and workouts support LifeBoard-originated write-back where the device, entitlement, permission, and record type allow it. HealthKit remains authoritative for imported samples; LifeBoard retains source identity for manual and outbound entries.

Permission can be not requested, denied, restricted, or unavailable while protected data is locked. Background observation may be delayed. Refresh in foreground, use manual fallback, and inspect stale/partial status. Failed write-back remains in a retryable outbox and must not appear as synced.

## Habits, routines, goals, and trackers

- Create a habit with schedule, target, reminder, and completion type. Quantity/count habits record a value, not just a checkmark.
- Use Quiet Tracking to log several habits with minimal friction and celebration.
- Correct the actual occurrence/date. Recovery repairs one intended miss; it does not rewrite the whole streak.
- Pause during illness/travel, archive when no longer active, and delete only after reading history consequences.
- Use routines for ordered or branching care/wellness actions; linked task/habit mutations execute once.
- Use goals with typed progress samples and linked tasks/habits/routines/trackers. Treat trajectory as a planning signal, especially when evidence is sparse.
- Track hydration, mood/energy, medication/care events, or generic measures. An explicit zero is a valid observation.

## Nutrition

Search the local food library, choose a serving/conversion, or build a recipe/meal template. Remote barcode lookup happens only after an explicit request and may be unavailable offline. Resolve duplicates before logging. A logged meal keeps its macro snapshot even if the source food later changes. Use the timeline, recent meals, reports, and goals; reports disclose incomplete days. Deleting a meal changes your LifeBoard history and offers Undo where supported.

## Fasting

Choose a target and start the timer. Finish early, cancel, or keep running deliberately; those are different outcomes. Notifications and Live Activity are conveniences, not the timer’s authority. History can be corrected, and startup repair resolves duplicate active sessions. Fasting is not a recommendation; follow appropriate professional guidance for your circumstances.

## Interpret evidence safely

Insights should name timeframe, source, and missing data. Open evidence before acting. Charts have text equivalents and must not imply causation. A relationship between sleep, mood, Focus, nutrition, or habits may be useful for reflection but is not a clinical conclusion.

## Privacy and correction

Health, care, nutrition, fasting, and related Journal evidence are sensitive. Limit Home/widget consent, lock the app where appropriate, and avoid attaching these categories to EVA without intent. Correct LifeBoard-owned samples in history. For HealthKit-owned data, use the owning source when LifeBoard cannot edit it.
