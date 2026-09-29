import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum StarterWorkspaceCatalog {
    static let coreLifeAreaIDs = ["work-career", "life-admin", "health-self"]
    static let optionalLifeAreaIDs = ["relationships", "learning-growth", "creativity-fun", "money"]

    static let legacyLifeAreaIDMap: [String: String] = [
        "career": "work-career",
        "home": "life-admin",
        "health": "health-self",
        "learning": "learning-growth",
        "money": "money"
    ]

    static let legacyProjectIDMap: [String: String] = [
        "career-ship": "work-ship",
        "career-followups": "work-followups",
        "career-admin": "work-admin",
        "home-reset": "life-home-reset",
        "home-laundry": "life-home-reset",
        "home-errands": "life-errands",
        "health-meal": "health-meals"
    ]

    static let taskTemplateIDRemap: [String: String] = [
        "task-home-laundry-basket": "task-home-reset-five",
        "task-learning-read-page": "task-health-reflect-page",
        "task-learning-read-takeaway": "task-health-reflect-takeaway"
    ]

    static let legacyHabitIDMap: [String: String] = [
        "habit-home-laundry": "habit-home-reset",
        "habit-learning-page": "habit-health-read-page"
    ]

    static let defaultProjectByFriction: [OnboardingFrictionProfile: [String: String]] = [
        .starting: [
            "work-career": "work-ship",
            "life-admin": "life-home-reset",
            "health-self": "health-move"
        ],
        .choosing: [
            "work-career": "work-followups",
            "life-admin": "life-bills-money",
            "health-self": "health-meals"
        ],
        .remembering: [
            "work-career": "work-followups",
            "life-admin": "life-appointments-paperwork",
            "health-self": "health-sleep"
        ],
        .finishing: [
            "work-career": "work-ship",
            "life-admin": "life-home-reset",
            "health-self": "health-recovery"
        ],
        .overwhelmed: [
            "work-career": "work-admin",
            "life-admin": "life-home-reset",
            "health-self": "health-recovery"
        ]
    ]

    static let primaryTaskIDByFriction: [OnboardingFrictionProfile: String] = [
        .starting: "task-career-ship-draft",
        .choosing: "task-money-bills-date",
        .remembering: "task-life-appointments-calendar",
        .finishing: "task-home-reset-surface",
        .overwhelmed: "task-home-reset-five"
    ]

    static let primaryHabitIDByFriction: [OnboardingFrictionProfile: String] = [
        .starting: "habit-health-water",
        .choosing: "habit-career-plan",
        .remembering: "habit-life-appointments-check",
        .finishing: "habit-work-must-move",
        .overwhelmed: "habit-health-reset-after-work"
    ]

    static let allLifeAreas: [StarterLifeAreaTemplate] = [
        area(
            id: "work-career",
            name: "Work & Career",
            subtitle: "Projects, follow-ups, and meetings",
            icon: "briefcase.fill",
            colorHex: "#B1205F",
            aliases: ["work", "career", "job", "office", "professional"],
            projects: [
                project(
                    id: "work-ship",
                    lifeAreaID: "work-career",
                    name: "Ship something",
                    summary: "Move the next deliverable forward.",
                    aliases: ["ship one thing", "deliverable", "work output"],
                    tasks: [
                        task(
                            id: "task-career-ship-draft",
                            projectID: "work-ship",
                            title: "Write 3 lines of the draft",
                            reason: "Starting is the hard part.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.starting]
                        ),
                        task(
                            id: "task-work-ship-bullet",
                            projectID: "work-ship",
                            title: "Write the spec’s first bullet",
                            reason: "A first line makes the next pass easier.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.finishing]
                        ),
                        task(
                            id: "task-work-ship-stub",
                            projectID: "work-ship",
                            title: "Set up the document file",
                            reason: "Gives the work a place to land.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.starting, .choosing]
                        )
                    ]
                ),
                project(
                    id: "work-followups",
                    lifeAreaID: "work-career",
                    name: "Follow-ups",
                    summary: "Loose ends that need a reply.",
                    aliases: ["followups", "follow up", "replies"],
                    tasks: [
                        task(
                            id: "task-career-followups-note",
                            projectID: "work-followups",
                            title: "Pick one follow-up to send",
                            reason: "Capture the name now, the message later.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .phone,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-career-ship-message",
                            projectID: "work-followups",
                            title: "Send one unblocker message",
                            reason: "One message can restart stalled work fast.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .phone,
                            recommendedProfiles: [.choosing, .finishing]
                        ),
                        task(
                            id: "task-work-followups-reply",
                            projectID: "work-followups",
                            title: "Reply to one pending thread",
                            reason: "A single reply closes a real loop.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.remembering]
                        )
                    ]
                ),
                project(
                    id: "work-meetings",
                    lifeAreaID: "work-career",
                    name: "Meetings & decisions",
                    summary: "Turn meetings into next steps.",
                    aliases: ["meetings", "decisions", "agendas"],
                    tasks: [
                        task(
                            id: "task-work-meetings-agenda",
                            projectID: "work-meetings",
                            title: "Add one agenda point",
                            reason: "An agenda keeps the meeting on track.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .meeting
                        ),
                        task(
                            id: "task-work-meetings-decision",
                            projectID: "work-meetings",
                            title: "Note the last meeting’s decision",
                            reason: "Written decisions don’t get lost.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        ),
                        task(
                            id: "task-work-meetings-next-action",
                            projectID: "work-meetings",
                            title: "Note the call’s next step",
                            reason: "Turns the meeting into action.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "work-admin",
                    lifeAreaID: "work-career",
                    name: "Work admin",
                    summary: "Small work chores that pile up.",
                    aliases: ["work admin reset", "admin", "ops", "cleanup"],
                    tasks: [
                        task(
                            id: "task-career-admin-email",
                            projectID: "work-admin",
                            title: "Archive one stale thread",
                            reason: "Closes a loop in seconds.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .computer,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-work-admin-downloads",
                            projectID: "work-admin",
                            title: "Clear one file from Downloads",
                            reason: "Less clutter on screen.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-work-admin-title",
                            projectID: "work-admin",
                            title: "Make one task title actionable",
                            reason: "Clear wording makes the next step obvious.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "work-growth",
                    lifeAreaID: "work-career",
                    name: "Career growth",
                    summary: "Skills and long-term goals.",
                    aliases: ["growth", "career growth", "skills"],
                    tasks: [
                        task(
                            id: "task-work-growth-idea",
                            projectID: "work-growth",
                            title: "Save one growth idea",
                            reason: "Saved ideas don’t get lost.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-work-growth-gap",
                            projectID: "work-growth",
                            title: "Note one skill gap",
                            reason: "Makes it easier to choose what to practice.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-work-growth-open-resource",
                            projectID: "work-growth",
                            title: "Open one saved learning resource",
                            reason: "Opening it is enough to restart.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        )
                    ]
                )
            ]
        ),
        area(
            id: "life-admin",
            name: "Home & Life Admin", // Renamed; old name kept in aliases so upsert still matches.
            subtitle: "Home, errands, paperwork, and bills",
            icon: "house.fill",
            colorHex: "#5C6AC4",
            aliases: ["life", "admin", "home", "paperwork", "errands", "personal admin", "life & admin"],
            projects: [
                project(
                    id: "life-home-reset",
                    lifeAreaID: "life-admin",
                    name: "Home reset",
                    summary: "Quick cleanups around the house.",
                    aliases: ["home reset", "reset", "tidy", "cleanup"],
                    tasks: [
                        task(
                            id: "task-home-reset-five",
                            projectID: "life-home-reset",
                            title: "Put away 5 things",
                            reason: "Concrete, finite, and quick.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-home-reset-surface",
                            projectID: "life-home-reset",
                            title: "Clear one surface",
                            reason: "You see the result right away.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.finishing]
                        ),
                        task(
                            id: "task-life-home-reset-trash",
                            projectID: "life-home-reset",
                            title: "Toss trash for 2 minutes",
                            reason: "A short sweep makes the room usable.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .maintenance,
                            context: .home,
                            recommendedProfiles: [.starting]
                        )
                    ]
                ),
                project(
                    id: "life-appointments-paperwork",
                    lifeAreaID: "life-admin",
                    name: "Appointments & paperwork",
                    summary: "Appointments, forms, and documents.",
                    aliases: ["appointments", "paperwork", "forms", "admin"],
                    tasks: [
                        task(
                            id: "task-life-appointments-book",
                            projectID: "life-appointments-paperwork",
                            title: "Book one appointment",
                            reason: "Booking is often the only real blocker.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone
                        ),
                        task(
                            id: "task-life-appointments-calendar",
                            projectID: "life-appointments-paperwork",
                            title: "Add one appointment to calendar",
                            reason: "Puts it where you’ll see it.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-life-appointments-document",
                            projectID: "life-appointments-paperwork",
                            title: "Photograph one document",
                            reason: "A photo now saves a search later.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone
                        ),
                        task(
                            id: "task-life-appointments-form",
                            projectID: "life-appointments-paperwork",
                            title: "Fill in one form field",
                            reason: "Keeps the form moving.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "life-errands",
                    lifeAreaID: "life-admin",
                    name: "Errands & shopping",
                    summary: "Errands and trips out.",
                    aliases: ["errands", "shopping", "pickup", "store"],
                    tasks: [
                        task(
                            id: "task-home-errands-note",
                            projectID: "life-errands",
                            title: "Write down one errand",
                            reason: "Gets it out of your head.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-group",
                            projectID: "life-errands",
                            title: "Batch 2 errands together",
                            reason: "One trip instead of two.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-hours",
                            projectID: "life-errands",
                            title: "Check store hours",
                            reason: "Turns an errand into a plan.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "life-bills-money",
                    lifeAreaID: "life-admin",
                    name: "Bills & money check-ins",
                    summary: "Bills, due dates, and charges.",
                    aliases: ["bills", "money", "finance", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-bills-date",
                            projectID: "life-bills-money",
                            title: "Check one bill’s due date",
                            reason: "Knowing the date removes the guesswork.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer,
                            recommendedProfiles: [.choosing]
                        ),
                        task(
                            id: "task-life-bills-reminder",
                            projectID: "life-bills-money",
                            title: "Set a due-date reminder",
                            reason: "One less thing to remember.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        ),
                        task(
                            id: "task-life-bills-charge",
                            projectID: "life-bills-money",
                            title: "Check one recent charge",
                            reason: "A quick look removes doubt.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "life-digital-reset",
                    lifeAreaID: "life-admin",
                    name: "Digital reset",
                    summary: "Fewer emails, files, and screenshots.",
                    aliases: ["digital reset", "inbox", "files", "cleanup"],
                    tasks: [
                        task(
                            id: "task-life-digital-unsubscribe",
                            projectID: "life-digital-reset",
                            title: "Unsubscribe from one email",
                            reason: "One fewer interruption later.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-rename",
                            projectID: "life-digital-reset",
                            title: "Rename one unclear file",
                            reason: "Easier to find later.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-delete",
                            projectID: "life-digital-reset",
                            title: "Delete old screenshots",
                            reason: "Less clutter in Photos.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "health-self",
            name: "Health & Self",
            subtitle: "Movement, sleep, food, and rest",
            icon: "heart.fill",
            colorHex: "#293A18",
            aliases: ["health", "self", "wellness", "energy", "recovery", "body"],
            projects: [
                project(
                    id: "health-move",
                    lifeAreaID: "health-self",
                    name: "Move your body",
                    summary: "Short movement to start the day.",
                    aliases: ["movement", "exercise", "workout"],
                    tasks: [
                        task(
                            id: "task-health-move-clothes",
                            projectID: "health-move",
                            title: "Put on workout clothes",
                            reason: "Makes the workout easier to start.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-move-water",
                            projectID: "health-move",
                            title: "Fill your water bottle",
                            reason: "Quick, with a clear finish.",
                            minutes: 1,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-move-walk",
                            projectID: "health-move",
                            title: "Walk for 10 minutes",
                            reason: "For days you want more movement.",
                            minutes: 10,
                            type: .morning,
                            energy: .medium,
                            category: .health,
                            context: .outdoor
                        )
                    ]
                ),
                project(
                    id: "health-sleep",
                    lifeAreaID: "health-self",
                    name: "Sleep wind-down",
                    summary: "Cues that help you stop at night.",
                    aliases: ["sleep", "rest", "bedtime"],
                    tasks: [
                        task(
                            id: "task-health-sleep-charge",
                            projectID: "health-sleep",
                            title: "Put your phone on charge",
                            reason: "Marks the start of winding down.",
                            minutes: 1,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home,
                            recommendedProfiles: [.remembering]
                        ),
                        task(
                            id: "task-health-sleep-night-mode",
                            projectID: "health-sleep",
                            title: "Turn on night mode",
                            reason: "A cue that bedtime is coming.",
                            minutes: 1,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .phone
                        ),
                        task(
                            id: "task-health-sleep-tomorrow",
                            projectID: "health-sleep",
                            title: "Set out tomorrow’s things",
                            reason: "Makes tomorrow morning easier.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-meals",
                    lifeAreaID: "health-self",
                    name: "Meal reset",
                    summary: "Simple food decisions, made early.",
                    aliases: ["food", "meals", "nutrition"],
                    tasks: [
                        task(
                            id: "task-health-meal-snack",
                            projectID: "health-meals",
                            title: "Put a snack in sight",
                            reason: "Makes a good choice the easy one.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-meal-list",
                            projectID: "health-meals",
                            title: "Pick tonight’s meal",
                            reason: "One decision, made early.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .anywhere,
                            recommendedProfiles: [.choosing]
                        ),
                        task(
                            id: "task-health-meal-prep",
                            projectID: "health-meals",
                            title: "Prep one simple ingredient",
                            reason: "Makes cooking later faster.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-recovery",
                    lifeAreaID: "health-self",
                    name: "Rest & recovery",
                    summary: "Short breaks and resets.",
                    aliases: ["recovery", "calm", "rest", "reset"],
                    tasks: [
                        task(
                            id: "task-health-recovery-reset",
                            projectID: "health-recovery",
                            title: "Take a 2-minute break",
                            reason: "A short pause resets the next hour.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .home,
                            recommendedProfiles: [.overwhelmed]
                        ),
                        task(
                            id: "task-health-recovery-outside",
                            projectID: "health-recovery",
                            title: "Step outside for 5 minutes",
                            reason: "Fresh air between tasks.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .outdoor
                        ),
                        task(
                            id: "task-health-recovery-breaths",
                            projectID: "health-recovery",
                            title: "Drink water, take 5 breaths",
                            reason: "Quick and concrete.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "health-reflect",
                    lifeAreaID: "health-self",
                    name: "Read & reflect",
                    summary: "Short daily reading and reflection.",
                    aliases: ["read", "reflect", "renewal"],
                    tasks: [
                        task(
                            id: "task-health-reflect-page",
                            projectID: "health-reflect",
                            title: "Read 1 page",
                            reason: "One page is easy to keep up.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-health-reflect-takeaway",
                            projectID: "health-reflect",
                            title: "Write 1 takeaway from yesterday",
                            reason: "One sentence closes the loop on the day.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-health-reflect-idea",
                            projectID: "health-reflect",
                            title: "Save one idea",
                            reason: "Saving it is enough for today.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "relationships",
            name: "Relationships",
            subtitle: "Family, friends, and plans",
            icon: "person.2.fill",
            colorHex: "#A53E6D",
            aliases: ["relationships", "friends", "family", "social"],
            projects: [
                project(
                    id: "relationships-partner-family",
                    lifeAreaID: "relationships",
                    name: "Partner / family",
                    summary: "Time with the people closest to you.",
                    aliases: ["partner", "family", "home people"],
                    tasks: [
                        task(
                            id: "task-relationships-family-text",
                            projectID: "relationships-partner-family",
                            title: "Send one check-in text",
                            reason: "A short message keeps you close.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-calendar",
                            projectID: "relationships-partner-family",
                            title: "Plan one family date",
                            reason: "A date on the calendar happens.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-question",
                            projectID: "relationships-partner-family",
                            title: "Note something to ask about",
                            reason: "A prompt makes the next conversation easier.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        )
                    ]
                ),
                project(
                    id: "relationships-friends",
                    lifeAreaID: "relationships",
                    name: "Friends",
                    summary: "Replies, plans, and check-ins.",
                    aliases: ["friends", "friendships"],
                    tasks: [
                        task(
                            id: "task-relationships-friends-reply",
                            projectID: "relationships-friends",
                            title: "Reply to one personal message",
                            reason: "One reply keeps the thread alive.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-friends-plan",
                            projectID: "relationships-friends",
                            title: "Suggest plans to a friend",
                            reason: "Specific plans are easier to say yes to.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-friends-list",
                            projectID: "relationships-friends",
                            title: "Pick a friend to text",
                            reason: "A name makes the next step clear.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        )
                    ]
                ),
                project(
                    id: "relationships-social-plans",
                    lifeAreaID: "relationships",
                    name: "Social plans",
                    summary: "Turn ideas into plans with people.",
                    aliases: ["social plans", "weekend plans", "hangouts"],
                    tasks: [
                        task(
                            id: "task-relationships-social-idea",
                            projectID: "relationships-social-plans",
                            title: "Note one weekend idea",
                            reason: "One idea gets plans started.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .anywhere
                        ),
                        task(
                            id: "task-relationships-social-invite",
                            projectID: "relationships-social-plans",
                            title: "Text one invite",
                            reason: "Sending matters more than wording.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-social-place",
                            projectID: "relationships-social-plans",
                            title: "Pick one time and place",
                            reason: "Specific plans are easier to finish.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "learning-growth",
            name: "Learning & Growth",
            subtitle: "Reading, study, and practice",
            icon: "book.fill",
            colorHex: "#9E5F0A",
            aliases: ["learning", "growth", "study", "practice"],
            projects: [
                project(
                    id: "learning-read",
                    lifeAreaID: "learning-growth",
                    name: "Read and capture",
                    summary: "Read, then save what stuck.",
                    aliases: ["read", "reading", "capture"],
                    tasks: [
                        task(
                            id: "task-learning-read-page",
                            projectID: "learning-read",
                            title: "Read 1 page",
                            reason: "One page is enough to restart.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-read-takeaway",
                            projectID: "learning-read",
                            title: "Write 1 takeaway from yesterday",
                            reason: "One sentence is enough.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-read-save",
                            projectID: "learning-read",
                            title: "Save one idea to revisit",
                            reason: "Saving it is progress.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "learning-study",
                    lifeAreaID: "learning-growth",
                    name: "Study session",
                    summary: "Short study sessions.",
                    aliases: ["study session", "course", "class"],
                    tasks: [
                        task(
                            id: "task-learning-study-open",
                            projectID: "learning-study",
                            title: "Open the study doc",
                            reason: "Opening it is often the hardest part.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-learning-study-question",
                            projectID: "learning-study",
                            title: "Write one question to answer",
                            reason: "A question gives the session a focus.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "learning-practice",
                    lifeAreaID: "learning-growth",
                    name: "Practice block",
                    summary: "Regular practice in short rounds.",
                    aliases: ["practice", "reps", "drills"],
                    tasks: [
                        task(
                            id: "task-learning-practice-minute",
                            projectID: "learning-practice",
                            title: "Do one 2-minute practice round",
                            reason: "Two minutes is enough to restart practice.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-practice-step",
                            projectID: "learning-practice",
                            title: "Pick what to practice next",
                            reason: "A named next rep is easier to start.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        )
                    ]
                )
            ]
        ),
        area(
            id: "creativity-fun",
            name: "Creativity & Fun",
            subtitle: "Hobbies, writing, and weekend plans",
            icon: "paintpalette.fill",
            colorHex: "#D97706",
            aliases: ["creativity", "fun", "hobby", "creative"],
            projects: [
                project(
                    id: "creativity-writing",
                    lifeAreaID: "creativity-fun",
                    name: "Personal writing",
                    summary: "Writing in short starts.",
                    aliases: ["writing", "journal", "notes"],
                    tasks: [
                        task(
                            id: "task-creativity-writing-lines",
                            projectID: "creativity-writing",
                            title: "Write 2 lines",
                            reason: "Two lines are enough to start.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-writing-title",
                            projectID: "creativity-writing",
                            title: "Give the idea a title",
                            reason: "A named idea is easier to return to.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "creativity-hobby",
                    lifeAreaID: "creativity-fun",
                    name: "Hobby practice",
                    summary: "Your hobby, in short sessions.",
                    aliases: ["hobby", "practice", "creative practice"],
                    tasks: [
                        task(
                            id: "task-creativity-hobby-materials",
                            projectID: "creativity-hobby",
                            title: "Set out your materials",
                            reason: "Less setup makes starting easier.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .home
                        ),
                        task(
                            id: "task-creativity-hobby-five",
                            projectID: "creativity-hobby",
                            title: "Do 5 minutes of practice",
                            reason: "Short sessions keep the hobby going.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .home
                        )
                    ]
                ),
                project(
                    id: "creativity-weekend",
                    lifeAreaID: "creativity-fun",
                    name: "Weekend ideas",
                    summary: "Save fun ideas before the week fills up.",
                    aliases: ["weekend", "fun plans", "ideas"],
                    tasks: [
                        task(
                            id: "task-creativity-weekend-idea",
                            projectID: "creativity-weekend",
                            title: "Note one fun idea",
                            reason: "Gives the week something to look forward to.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-weekend-save",
                            projectID: "creativity-weekend",
                            title: "Save a place to try",
                            reason: "Saved ideas don’t get lost.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .phone
                        )
                    ]
                )
            ]
        ),
        area(
            id: "money",
            name: "Money",
            subtitle: "Bills, budget, and money errands",
            icon: "dollarsign.circle.fill",
            colorHex: "#2E8B57",
            aliases: ["finance", "finances", "budget"],
            projects: [
                project(
                    id: "money-bills",
                    lifeAreaID: "money",
                    name: "Bills this week",
                    summary: "Due dates and payments this week.",
                    aliases: ["bills", "payments", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-standalone-bills-date",
                            projectID: "money-bills",
                            title: "Check one bill’s due date",
                            reason: "Knowing the date removes the guesswork.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        ),
                        task(
                            id: "task-money-standalone-reminder",
                            projectID: "money-bills",
                            title: "Set a due-date reminder",
                            reason: "One less thing to remember.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        )
                    ]
                ),
                project(
                    id: "money-budget",
                    lifeAreaID: "money",
                    name: "Budget reset",
                    summary: "A quick look at spending.",
                    aliases: ["budget", "spending", "plan"],
                    tasks: [
                        task(
                            id: "task-money-budget-receipt",
                            projectID: "money-budget",
                            title: "File one receipt",
                            reason: "One receipt at a time.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        ),
                        task(
                            id: "task-money-budget-charge",
                            projectID: "money-budget",
                            title: "Check one recent charge",
                            reason: "A quick look removes doubt.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        )
                    ]
                ),
                project(
                    id: "money-errands",
                    lifeAreaID: "money",
                    name: "Financial errands",
                    summary: "Bank and paperwork errands.",
                    aliases: ["financial errands", "bank", "paperwork"],
                    tasks: [
                        task(
                            id: "task-money-errands-note",
                            projectID: "money-errands",
                            title: "Write down one money errand",
                            reason: "Writing it down makes the next step clear.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .anywhere
                        ),
                        task(
                            id: "task-money-errands-hours",
                            projectID: "money-errands",
                            title: "Check bank or office hours",
                            reason: "Knowing the hours makes it easier to plan.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .phone
                        )
                    ]
                )
            ]
        )
    ]

    static let allHabitTemplates: [StarterHabitTemplate] = [
        positiveHabit(
            id: "habit-career-plan",
            lifeAreaID: "work-career",
            projectID: "work-ship",
            title: "Choose tomorrow's first work step",
            reason: "Tomorrow starts with a decision made.",
            cadence: .daily(hour: 17, minute: 30),
            symbol: "briefcase.fill",
            categoryKey: "work",
            notes: "One specific next step.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-work-must-move",
            lifeAreaID: "work-career",
            projectID: "work-ship",
            title: "Name one must-move task",
            reason: "Tomorrow starts with a clear first task.",
            cadence: .daily(hour: 17, minute: 45),
            symbol: "flag.fill",
            categoryKey: "work",
            notes: "One task, not a list.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-career-followups",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Check follow-ups every weekday",
            reason: "Keeps important threads moving.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 16, minute: 0),
            symbol: "tray.full.fill",
            categoryKey: "work",
            notes: "A scan, not a clear-out.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-work-waiting-on",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Check what you’re waiting on",
            reason: "A short pass keeps loose ends visible.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 17, minute: 0),
            symbol: "clock.badge.checkmark.fill",
            categoryKey: "work",
            notes: "A short review is enough.",
            recommendedProfiles: [.remembering, .finishing]
        ),

        positiveHabit(
            id: "habit-home-reset",
            lifeAreaID: "life-admin",
            projectID: "life-home-reset",
            title: "Do a 2-minute home reset",
            reason: "Short resets keep the house usable.",
            cadence: .daily(hour: 20, minute: 0),
            symbol: "house.fill",
            categoryKey: "life",
            notes: "Stop at 2 minutes.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-life-surface",
            lifeAreaID: "life-admin",
            projectID: "life-home-reset",
            title: "Clear one surface each evening",
            reason: "One surface, not the whole room.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "sparkles",
            categoryKey: "life",
            notes: "Pick one surface.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-life-appointments-check",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Check appointments twice a week",
            reason: "No surprise appointments.",
            cadence: .weekly(daysOfWeek: [2, 5], hour: 18, minute: 0),
            symbol: "calendar.badge.clock",
            categoryKey: "life",
            notes: "Look at what’s coming up.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-life-paperwork-capture",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Put paperwork in one spot",
            reason: "One place for all paperwork.",
            cadence: .weekly(daysOfWeek: [2, 4, 6], hour: 18, minute: 30),
            symbol: "tray.and.arrow.down.fill",
            categoryKey: "life",
            notes: "Sort it later.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-life-errands-review",
            lifeAreaID: "life-admin",
            projectID: "life-errands",
            title: "Review errands before leaving home",
            reason: "A quick glance makes the trip more useful.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6, 7], hour: 9, minute: 0),
            symbol: "car.fill",
            categoryKey: "life",
            notes: "Check only when it helps.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-life-bill-check",
            lifeAreaID: "life-admin",
            projectID: "life-bills-money",
            title: "Friday bill check",
            reason: "Know what’s due this week.",
            cadence: .weekly(daysOfWeek: [6], hour: 11, minute: 0),
            symbol: "creditcard.fill",
            categoryKey: "life",
            notes: "A look, not a budget session.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-money-check",
            lifeAreaID: "life-admin",
            projectID: "life-bills-money",
            title: "Weekly account glance",
            reason: "A short look instead of a budget session.",
            cadence: .weekly(daysOfWeek: [6], hour: 12, minute: 0),
            symbol: "dollarsign.circle.fill",
            categoryKey: "life",
            notes: "A quick look is enough.",
            recommendedProfiles: [.choosing, .remembering]
        ),
        positiveHabit(
            id: "habit-life-digital-cleanup",
            lifeAreaID: "life-admin",
            projectID: "life-digital-reset",
            title: "Weekly 5-minute inbox cleanup",
            reason: "A short cleanup keeps the inbox manageable.",
            cadence: .weekly(daysOfWeek: [7], hour: 18, minute: 0),
            symbol: "envelope.badge.fill",
            categoryKey: "life",
            notes: "5 minutes is enough.",
            recommendedProfiles: [.overwhelmed]
        ),

        positiveHabit(
            id: "habit-health-water",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Drink water after you wake up",
            reason: "Easy to remember and takes seconds.",
            cadence: .daily(hour: 8, minute: 0),
            symbol: "drop.fill",
            categoryKey: "health",
            notes: "One glass is enough.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-move-five",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Move 5 minutes each morning",
            reason: "Short movement is easier to keep up.",
            cadence: .daily(hour: 8, minute: 30),
            symbol: "figure.walk",
            categoryKey: "health",
            notes: "5 minutes is enough.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-charge",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Charge your phone before bed",
            reason: "A clear signal that bedtime is near.",
            cadence: .daily(hour: 21, minute: 30),
            symbol: "bed.double.fill",
            categoryKey: "health",
            notes: "Charge it away from the bed.",
            recommendedProfiles: [.remembering]
        ),
        negativeHabit(
            id: "habit-health-no-phone-bed",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "No phone in bed",
            reason: "Better wind-down before sleep.",
            cadence: .daily(hour: 22, minute: 0),
            symbol: "moon.zzz.fill",
            categoryKey: "health",
            notes: "Log a slip and keep going.",
            recommendedProfiles: [.remembering, .overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-same-wind-down",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Regular wind-down time",
            reason: "A regular cue makes stopping easier.",
            cadence: .daily(hour: 21, minute: 0),
            symbol: "moon.stars.fill",
            categoryKey: "health",
            notes: "Roughly on time is fine.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-health-lunch",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Decide lunch before noon",
            reason: "Lunch is decided before you’re hungry.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 11, minute: 0),
            symbol: "fork.knife",
            categoryKey: "health",
            notes: "A rough plan is fine.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-health-snack",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Eat one protein-first snack daily",
            reason: "A reliable snack makes good choices simpler.",
            cadence: .daily(hour: 15, minute: 0),
            symbol: "leaf.fill",
            categoryKey: "health",
            notes: "Keep it simple.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-health-reset-after-work",
            lifeAreaID: "health-self",
            projectID: "health-recovery",
            title: "2-minute reset after work",
            reason: "A short break between work and evening.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 18, minute: 0),
            symbol: "figure.mind.and.body",
            categoryKey: "health",
            notes: "2 minutes is enough.",
            recommendedProfiles: [.overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-check-energy",
            lifeAreaID: "health-self",
            projectID: "health-recovery",
            title: "Check energy before adding more",
            reason: "Know your energy before you commit.",
            cadence: .daily(hour: 14, minute: 0),
            symbol: "bolt.heart.fill",
            categoryKey: "health",
            notes: "Pause before saying yes.",
            recommendedProfiles: [.overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-read-page",
            lifeAreaID: "health-self",
            projectID: "health-reflect",
            title: "Read one page each evening",
            reason: "A short daily read is easier to keep.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "book.fill",
            categoryKey: "health",
            notes: "One page is enough.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-takeaway",
            lifeAreaID: "health-self",
            projectID: "health-reflect",
            title: "Capture one takeaway before bed",
            reason: "One takeaway helps the day feel finished.",
            cadence: .daily(hour: 21, minute: 15),
            symbol: "text.quote",
            categoryKey: "health",
            notes: "One sentence is enough.",
            recommendedProfiles: [.finishing]
        ),

        positiveHabit(
            id: "habit-relationships-check-in",
            lifeAreaID: "relationships",
            projectID: "relationships-friends",
            title: "Weekly check-in with someone",
            reason: "A short message keeps people close.",
            cadence: .weekly(daysOfWeek: [7], hour: 16, minute: 0),
            symbol: "person.crop.circle.badge.plus",
            categoryKey: "relationships",
            notes: "One person is enough.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-learning-capture",
            lifeAreaID: "learning-growth",
            projectID: "learning-read",
            title: "Capture one thing you learned",
            reason: "A small capture helps learning stick.",
            cadence: .daily(hour: 20, minute: 0),
            symbol: "graduationcap.fill",
            categoryKey: "learning",
            notes: "One idea is enough.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-creativity-make",
            lifeAreaID: "creativity-fun",
            projectID: "creativity-hobby",
            title: "Make something for 10 minutes",
            reason: "Short sessions are easier to keep up.",
            cadence: .weekly(daysOfWeek: [3, 7], hour: 19, minute: 0),
            symbol: "paintbrush.pointed.fill",
            categoryKey: "creativity",
            notes: "Stop at 10 minutes if you like.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-money-glance",
            lifeAreaID: "money",
            projectID: "money-budget",
            title: "Weekly account glance",
            reason: "A short look keeps money in view.",
            cadence: .weekly(daysOfWeek: [7], hour: 12, minute: 0),
            symbol: "banknote.fill",
            categoryKey: "money",
            notes: "Look without fixing anything.",
            recommendedProfiles: []
        )
    ]

    static func normalizeLifeAreaTemplateID(_ id: String) -> String {
        legacyLifeAreaIDMap[id] ?? id
    }

    static func normalizeProjectTemplateID(_ id: String) -> String {
        legacyProjectIDMap[id] ?? id
    }

    static func normalizeTaskTemplateID(_ id: String) -> String {
        taskTemplateIDRemap[id] ?? id
    }

    static func normalizeHabitTemplateID(_ id: String) -> String {
        legacyHabitIDMap[id] ?? id
    }

    static func normalizedProjectDraft(_ draft: OnboardingProjectDraft) -> OnboardingProjectDraft {
        let normalizedAreaID = normalizeLifeAreaTemplateID(draft.lifeAreaTemplateID)
        let normalizedTemplateID = normalizeProjectTemplateID(draft.templateID)
        let normalizedSuggestions = draft.suggestionTemplateIDs
            .map(normalizeProjectTemplateID)
            .reduce(into: [String]()) { partialResult, id in
                guard partialResult.contains(id) == false else { return }
                partialResult.append(id)
            }
        let matchedIndex = normalizedSuggestions.firstIndex(of: normalizedTemplateID) ?? 0
        let template = projectTemplate(id: normalizedTemplateID)
        return OnboardingProjectDraft(
            id: draft.id,
            lifeAreaTemplateID: normalizedAreaID,
            templateID: normalizedTemplateID,
            name: draft.name.isEmpty ? (template?.name ?? draft.name) : draft.name,
            summary: draft.summary.isEmpty ? (template?.summary ?? draft.summary) : draft.summary,
            suggestionTemplateIDs: normalizedSuggestions,
            suggestionIndex: matchedIndex,
            isSelected: draft.isSelected
        )
    }

    static func normalizedLifeAreaSelection(_ selection: ResolvedLifeAreaSelection) -> ResolvedLifeAreaSelection {
        ResolvedLifeAreaSelection(
            templateID: normalizeLifeAreaTemplateID(selection.templateID),
            lifeArea: selection.lifeArea,
            reusedExisting: selection.reusedExisting
        )
    }

    static func normalizedProjectSelection(_ selection: ResolvedProjectSelection) -> ResolvedProjectSelection {
        ResolvedProjectSelection(
            draft: normalizedProjectDraft(selection.draft),
            project: selection.project,
            reusedExisting: selection.reusedExisting
        )
    }

    static func normalizedTaskTemplateMap(_ map: [String: UUID]) -> [String: UUID] {
        map.reduce(into: [:]) { partialResult, entry in
            partialResult[normalizeTaskTemplateID(entry.key)] = entry.value
        }
    }

    static func normalizedHabitTemplateMap(_ map: [String: UUID]) -> [String: UUID] {
        map.reduce(into: [:]) { partialResult, entry in
            partialResult[normalizeHabitTemplateID(entry.key)] = entry.value
        }
    }

    static func lifeAreaTemplate(id: String) -> StarterLifeAreaTemplate? {
        let normalizedID = normalizeLifeAreaTemplateID(id)
        return allLifeAreas.first(where: { $0.id == normalizedID })
    }

    static func projectTemplate(id: String) -> StarterProjectTemplate? {
        let normalizedID = normalizeProjectTemplateID(id)
        return allLifeAreas
            .flatMap(\.projects)
            .first(where: { $0.id == normalizedID })
    }

    static func habitTemplate(id: String) -> StarterHabitTemplate? {
        let normalizedID = normalizeHabitTemplateID(id)
        return allHabitTemplates.first(where: { $0.id == normalizedID })
    }

    static func defaultLifeAreaSelectionIDs(
        for frictionProfile: OnboardingFrictionProfile?,
        mode: OnboardingMode
    ) -> [String] {
        let guided: [String]
        switch frictionProfile {
        case .starting:
            guided = ["work-career", "health-self", "life-admin"]
        case .choosing:
            guided = ["work-career", "life-admin", "health-self"]
        case .remembering:
            guided = ["life-admin", "work-career", "health-self"]
        case .finishing:
            guided = ["work-career", "life-admin", "health-self"]
        case .overwhelmed:
            guided = ["life-admin", "health-self", "work-career"]
        case .none:
            guided = ["work-career", "life-admin", "health-self"]
        }

        if mode == .custom {
            return Array(guided.prefix(1))
        }
        return guided
    }

    static func orderedLifeAreas(for frictionProfile: OnboardingFrictionProfile?) -> [StarterLifeAreaTemplate] {
        let coreIDs = defaultLifeAreaSelectionIDs(for: frictionProfile, mode: .guided)
        return (coreIDs + optionalLifeAreaIDs).compactMap(lifeAreaTemplate(id:))
    }

    static func visibleLifeAreas(
        for frictionProfile: OnboardingFrictionProfile?,
        showAll: Bool
    ) -> [StarterLifeAreaTemplate] {
        let ordered = orderedLifeAreas(for: frictionProfile)
        guard showAll == false else { return ordered }
        return Array(ordered.prefix(coreLifeAreaIDs.count))
    }

    static func defaultProjectDrafts(
        for selectedLifeAreaIDs: [String],
        mode: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        defaultProjectDrafts(for: selectedLifeAreaIDs, frictionProfile: nil, mode: mode)
    }

    static func defaultProjectDrafts(
        for selectedLifeAreaIDs: [String],
        frictionProfile: OnboardingFrictionProfile?,
        mode _: OnboardingMode
    ) -> [OnboardingProjectDraft] {
        selectedLifeAreaIDs.compactMap { selectedID in
            guard let area = lifeAreaTemplate(id: selectedID) else { return nil }
            let preferredProjectID = frictionProfile.flatMap { defaultProjectByFriction[$0]?[area.id] }
            let project = preferredProjectID.flatMap(projectTemplate(id:)) ?? area.projects.first
            guard let project else { return nil }
            let suggestionIDs = area.projects.map(\.id)
            let suggestionIndex = suggestionIDs.firstIndex(of: project.id) ?? 0
            return OnboardingProjectDraft(
                lifeAreaTemplateID: area.id,
                templateID: project.id,
                name: project.name,
                summary: project.summary,
                suggestionTemplateIDs: suggestionIDs,
                suggestionIndex: suggestionIndex,
                isSelected: true
            )
        }
    }

    static func taskSuggestions(
        for projects: [ResolvedProjectSelection],
        frictionProfile: OnboardingFrictionProfile?
    ) -> [StarterTaskTemplate] {
        projects
            .flatMap { project in
                projectTemplate(id: project.draft.templateID)?.taskTemplates ?? []
            }
            .sorted { lhs, rhs in
                score(task: lhs, frictionProfile: frictionProfile) > score(task: rhs, frictionProfile: frictionProfile)
            }
    }

    static func habitSuggestions(
        for projects: [ResolvedProjectSelection],
        frictionProfile: OnboardingFrictionProfile?
    ) -> [StarterHabitTemplate] {
        let selectedAreaIDs = Set(projects.map { normalizeLifeAreaTemplateID($0.draft.lifeAreaTemplateID) })
        let selectedProjectTemplateIDs = Set(projects.map { normalizeProjectTemplateID($0.draft.templateID) })
        let ranked = allHabitTemplates
            .filter { selectedAreaIDs.contains($0.lifeAreaTemplateID) }
            .filter { template in
                guard template.isPositive == false else { return true }
                guard let projectTemplateID = template.projectTemplateID else { return false }
                return selectedProjectTemplateIDs.contains(projectTemplateID)
            }
            .sorted { lhs, rhs in
                score(habit: lhs, selectedProjectTemplateIDs: selectedProjectTemplateIDs, frictionProfile: frictionProfile)
                    > score(habit: rhs, selectedProjectTemplateIDs: selectedProjectTemplateIDs, frictionProfile: frictionProfile)
            }

        let positives = ranked.filter(\.isPositive)
        let negatives = ranked.filter { $0.isPositive == false }
        var ordered: [StarterHabitTemplate] = Array(positives.prefix(5))
        if let firstNegative = negatives.first {
            ordered.append(firstNegative)
        }
        return ordered
    }

    static func defaultFallbackTaskTemplate(for projectTemplateID: String) -> StarterTaskTemplate {
        StarterTaskTemplate(
            id: "fallback-\(normalizeProjectTemplateID(projectTemplateID))",
            projectTemplateID: normalizeProjectTemplateID(projectTemplateID),
            title: "Pick this project’s next step",
            reason: "A first step to get oriented.",
            durationMinutes: 2,
            priority: .low,
            type: .morning,
            energy: .low,
            category: .general,
            context: .anywhere,
            dueDateIntent: .today,
            isQuickWin: true,
            clearDoneState: true,
            recommendedProfiles: []
        )
    }

    static func matchingLifeArea(
        for template: StarterLifeAreaTemplate,
        in existing: [LifeArea]
    ) -> LifeArea? {
        let candidateNames = Set(([template.name] + template.aliases).map(normalizedName))
        return existing.first(where: { candidateNames.contains(normalizedName($0.name)) })
    }

    static func matchingProject(
        for draft: OnboardingProjectDraft,
        lifeAreaID: UUID?,
        in existing: [Project]
    ) -> Project? {
        let normalizedDraft = normalizedProjectDraft(draft)
        let template = projectTemplate(id: normalizedDraft.templateID)
        let candidateNames = Set(
            ([normalizedDraft.name] + (template?.aliases ?? []) + [template?.name].compactMap { $0 })
                .map(normalizedName)
        )
        let candidates = existing.filter { candidateNames.contains(normalizedName($0.name)) }
        if let preferred = candidates.first(where: { $0.lifeAreaID == lifeAreaID }) {
            return preferred
        }
        return candidates.first
    }

    static func normalizedName(_ name: String) -> String {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(filtered).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func isCustomLifeArea(_ lifeArea: LifeArea) -> Bool {
        lifeArea.isArchived == false && normalizedName(lifeArea.name) != "general"
    }

    static func isCustomProject(_ project: Project) -> Bool {
        project.isArchived == false && project.isInbox == false && project.isDefault == false
    }

    static func score(task: StarterTaskTemplate, frictionProfile: OnboardingFrictionProfile?) -> Int {
        var score = 0
        score += task.isQuickWin ? 40 : 18
        score += task.clearDoneState ? 22 : 0
        score += task.durationMinutes <= 5 ? 10 : 0
        if let frictionProfile, task.recommendedProfiles.contains(frictionProfile) {
            score += 18
        }
        if let frictionProfile, primaryTaskIDByFriction[frictionProfile] == task.id {
            score += 120
        }
        switch task.context {
        case .computer, .phone, .home, .anywhere:
            score += 4
        default:
            break
        }
        return score
    }

    static func score(
        habit: StarterHabitTemplate,
        selectedProjectTemplateIDs: Set<String>,
        frictionProfile: OnboardingFrictionProfile?
    ) -> Int {
        var score = habit.isPositive ? 55 : 22
        if let projectTemplateID = habit.projectTemplateID,
           selectedProjectTemplateIDs.contains(projectTemplateID) {
            score += 18
        }
        if let frictionProfile, habit.recommendedProfiles.contains(frictionProfile) {
            score += 14
        }
        if let frictionProfile, primaryHabitIDByFriction[frictionProfile] == habit.id {
            score += 120
        }
        switch habit.cadence {
        case .daily:
            score += 8
        case .weekly:
            score += 4
        case .interval:
            score += 5
        }
        if habit.reason.localizedCaseInsensitiveContains("easy")
            || habit.reason.localizedCaseInsensitiveContains("seconds")
            || habit.reason.localizedCaseInsensitiveContains("tiny")
            || habit.reason.localizedCaseInsensitiveContains("short") {
            score += 6
        }
        return score
    }

    static func area(
        id: String,
        name: String,
        subtitle: String,
        icon: String,
        colorHex: String,
        aliases: [String],
        projects: [StarterProjectTemplate]
    ) -> StarterLifeAreaTemplate {
        StarterLifeAreaTemplate(
            id: id,
            name: name,
            subtitle: subtitle,
            icon: icon,
            colorHex: colorHex,
            aliases: aliases,
            projects: projects
        )
    }

    static func project(
        id: String,
        lifeAreaID: String,
        name: String,
        summary: String,
        aliases: [String],
        tasks: [StarterTaskTemplate]
    ) -> StarterProjectTemplate {
        StarterProjectTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            name: name,
            summary: summary,
            aliases: aliases,
            taskTemplates: tasks
        )
    }

    static func task(
        id: String,
        projectID: String,
        title: String,
        reason: String,
        minutes: Int,
        priority: TaskPriority = .low,
        type: TaskType,
        energy: TaskEnergy,
        category: TaskCategory,
        context: TaskContext,
        dueDateIntent: AddTaskPrefillDueIntent = .today,
        isQuickWin: Bool? = nil,
        clearDoneState: Bool = true,
        recommendedProfiles: [OnboardingFrictionProfile] = []
    ) -> StarterTaskTemplate {
        StarterTaskTemplate(
            id: id,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            durationMinutes: minutes,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            dueDateIntent: dueDateIntent,
            isQuickWin: isQuickWin ?? (minutes <= 5),
            clearDoneState: clearDoneState,
            recommendedProfiles: Set(recommendedProfiles)
        )
    }

    static func positiveHabit(
        id: String,
        lifeAreaID: String,
        projectID: String?,
        title: String,
        reason: String,
        cadence: HabitCadenceDraft,
        symbol: String,
        categoryKey: String,
        notes: String?,
        recommendedProfiles: [OnboardingFrictionProfile]
    ) -> StarterHabitTemplate {
        StarterHabitTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: cadence,
            icon: HabitIconMetadata(symbolName: symbol, categoryKey: categoryKey),
            notes: notes,
            recommendedProfiles: Set(recommendedProfiles)
        )
    }

    static func negativeHabit(
        id: String,
        lifeAreaID: String,
        projectID: String?,
        title: String,
        reason: String,
        cadence: HabitCadenceDraft,
        symbol: String,
        categoryKey: String,
        notes: String?,
        recommendedProfiles: [OnboardingFrictionProfile]
    ) -> StarterHabitTemplate {
        StarterHabitTemplate(
            id: id,
            lifeAreaTemplateID: lifeAreaID,
            projectTemplateID: projectID,
            title: title,
            reason: reason,
            kind: .negative,
            trackingMode: .dailyCheckIn,
            cadence: cadence,
            icon: HabitIconMetadata(symbolName: symbol, categoryKey: categoryKey),
            notes: notes,
            recommendedProfiles: Set(recommendedProfiles)
        )
    }
}
