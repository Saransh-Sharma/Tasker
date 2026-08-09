public enum MoodDialPersistence {
    public static func openingMood(for savedMood: Mood) -> Mood {
        Mood.dialMoods.contains(savedMood) ? savedMood : .none
    }

    public static func shouldSave(originalMood: Mood, draftMood: Mood) -> Bool {
        originalMood != draftMood
    }
}
