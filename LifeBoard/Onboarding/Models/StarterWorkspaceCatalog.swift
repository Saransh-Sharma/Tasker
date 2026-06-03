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

    static let legacyTaskIDMap: [String: String] = [
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
            subtitle: "Ship work, close loops, and stay ahead of drift",
            icon: "briefcase.fill",
            colorHex: "#B1205F",
            aliases: ["work", "career", "job", "office", "professional"],
            projects: [
                project(
                    id: "work-ship",
                    lifeAreaID: "work-career",
                    name: "Ship something",
                    summary: "Keep the next visible output moving.",
                    aliases: ["ship one thing", "deliverable", "work output"],
                    tasks: [
                        task(
                            id: "task-career-ship-draft",
                            projectID: "work-ship",
                            title: "Open the draft and write 3 lines",
                            reason: "It removes the hard part: getting started.",
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
                            title: "Write the first bullet of the spec",
                            reason: "A small visible output makes the next pass easier.",
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
                            title: "Rename the file and create the document stub",
                            reason: "This creates a place for the work to land.",
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
                    summary: "Keep important loose ends from disappearing.",
                    aliases: ["followups", "follow up", "replies"],
                    tasks: [
                        task(
                            id: "task-career-followups-note",
                            projectID: "work-followups",
                            title: "Write the name of one person to follow up with",
                            reason: "Capture first, decide the full message second.",
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
                    summary: "Turn meetings into next actions, not memory burden.",
                    aliases: ["meetings", "decisions", "agendas"],
                    tasks: [
                        task(
                            id: "task-work-meetings-agenda",
                            projectID: "work-meetings",
                            title: "Write one agenda point for today's meeting",
                            reason: "One agenda note keeps the meeting from becoming drift.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .work,
                            context: .meeting
                        ),
                        task(
                            id: "task-work-meetings-decision",
                            projectID: "work-meetings",
                            title: "Capture one decision from the last meeting",
                            reason: "Writing it down stops the decision from dissolving.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .work,
                            context: .computer
                        ),
                        task(
                            id: "task-work-meetings-next-action",
                            projectID: "work-meetings",
                            title: "Write one next action from the call",
                            reason: "A meeting only helps when it becomes action.",
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
                    summary: "Reduce drag from small but persistent work chores.",
                    aliases: ["work admin reset", "admin", "ops", "cleanup"],
                    tasks: [
                        task(
                            id: "task-career-admin-email",
                            projectID: "work-admin",
                            title: "Archive one stale thread",
                            reason: "It closes a loop with almost no setup cost.",
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
                            title: "Clean one desktop/downloads item",
                            reason: "A tiny cleanup lowers the visual tax immediately.",
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
                            title: "Update one task title so it is actionable",
                            reason: "Clear wording makes the next step easier to trust.",
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
                    summary: "Keep long-term growth visible without turning it into homework.",
                    aliases: ["growth", "career growth", "skills"],
                    tasks: [
                        task(
                            id: "task-work-growth-idea",
                            projectID: "work-growth",
                            title: "Save one growth idea",
                            reason: "Capturing one idea keeps it from vanishing.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-work-growth-gap",
                            projectID: "work-growth",
                            title: "Write one note about a skill gap",
                            reason: "Naming it makes future practice easier to choose.",
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
                            reason: "Re-entry counts even when you only open the tab.",
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
            name: "Life & Admin",
            subtitle: "Home, errands, paperwork, and money in one place",
            icon: "house.fill",
            colorHex: "#5C6AC4",
            aliases: ["life", "admin", "home", "paperwork", "errands", "personal admin"],
            projects: [
                project(
                    id: "life-home-reset",
                    lifeAreaID: "life-admin",
                    name: "Home reset",
                    summary: "Small cleanup tasks that make your space easier to use.",
                    aliases: ["home reset", "reset", "tidy", "cleanup"],
                    tasks: [
                        task(
                            id: "task-home-reset-five",
                            projectID: "life-home-reset",
                            title: "Put away 5 things",
                            reason: "It is concrete, finite, and hard to overthink.",
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
                            reason: "One visible patch of calm counts immediately.",
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
                            title: "Throw away obvious trash for 2 minutes",
                            reason: "A short sweep makes the room easier to re-enter.",
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
                    summary: "Track appointments, forms, and admin before they become stress.",
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
                            reason: "Putting it where you will see it prevents it from vanishing again.",
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
                            reason: "Capturing the document now lowers later friction.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .personal,
                            context: .phone
                        ),
                        task(
                            id: "task-life-appointments-form",
                            projectID: "life-appointments-paperwork",
                            title: "Fill one field on a form",
                            reason: "A tiny slice keeps the admin loop moving.",
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
                    summary: "Move outside-the-house loose ends forward.",
                    aliases: ["errands", "shopping", "pickup", "store"],
                    tasks: [
                        task(
                            id: "task-home-errands-note",
                            projectID: "life-errands",
                            title: "Write one errand in one place",
                            reason: "This gets it out of your head before it vanishes again.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-group",
                            projectID: "life-errands",
                            title: "Group two errands into one trip",
                            reason: "Bundling lowers the activation cost later.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .shopping,
                            context: .errands
                        ),
                        task(
                            id: "task-life-errands-hours",
                            projectID: "life-errands",
                            title: "Check store hours for one stop",
                            reason: "Knowing the constraint turns it into a real plan.",
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
                    summary: "Remove uncertainty around bills and basic money upkeep.",
                    aliases: ["bills", "money", "finance", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-bills-date",
                            projectID: "life-bills-money",
                            title: "Open one bill and check the due date",
                            reason: "Knowing the date is a real win and lowers dread.",
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
                            title: "Add one due date to reminders",
                            reason: "One reminder is enough to stop carrying it in your head.",
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
                            reason: "One quick glance reduces uncertainty fast.",
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
                    summary: "Reduce digital clutter that silently taxes attention.",
                    aliases: ["digital reset", "inbox", "files", "cleanup"],
                    tasks: [
                        task(
                            id: "task-life-digital-unsubscribe",
                            projectID: "life-digital-reset",
                            title: "Unsubscribe from one email",
                            reason: "Removing one future interruption is a real win.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-rename",
                            projectID: "life-digital-reset",
                            title: "Rename one file so it is searchable",
                            reason: "Future-you benefits from one clean label.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .maintenance,
                            context: .computer
                        ),
                        task(
                            id: "task-life-digital-delete",
                            projectID: "life-digital-reset",
                            title: "Delete one useless screenshot batch",
                            reason: "A tiny cleanup cuts visual noise quickly.",
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
            subtitle: "Protect energy, movement, sleep, and recovery without pressure",
            icon: "heart.fill",
            colorHex: "#293A18",
            aliases: ["health", "self", "wellness", "energy", "recovery", "body"],
            projects: [
                project(
                    id: "health-move",
                    lifeAreaID: "health-self",
                    name: "Move your body",
                    summary: "Small movement that gets the day unstuck.",
                    aliases: ["movement", "exercise", "workout"],
                    tasks: [
                        task(
                            id: "task-health-move-clothes",
                            projectID: "health-move",
                            title: "Put on workout clothes",
                            reason: "It is small enough to begin and makes the next move easier.",
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
                            reason: "It gives you an instant win with a clear done state.",
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
                            reason: "A good backup option when you want a little more movement.",
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
                    summary: "Tiny cues that make stopping easier later.",
                    aliases: ["sleep", "rest", "bedtime"],
                    tasks: [
                        task(
                            id: "task-health-sleep-charge",
                            projectID: "health-sleep",
                            title: "Put your phone on the charger",
                            reason: "One visible action can mark the start of winding down.",
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
                            reason: "A small cue makes the later stop easier.",
                            minutes: 1,
                            type: .evening,
                            energy: .low,
                            category: .health,
                            context: .phone
                        ),
                        task(
                            id: "task-health-sleep-tomorrow",
                            projectID: "health-sleep",
                            title: "Set out what you need for tomorrow morning",
                            reason: "Lowering tomorrow's startup cost also helps you stop tonight.",
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
                    summary: "Reduce food friction before it gets loud.",
                    aliases: ["food", "meals", "nutrition"],
                    tasks: [
                        task(
                            id: "task-health-meal-snack",
                            projectID: "health-meals",
                            title: "Put one easy snack where you can see it",
                            reason: "This lowers the energy needed to make the next decent choice.",
                            minutes: 2,
                            type: .morning,
                            energy: .low,
                            category: .health,
                            context: .home
                        ),
                        task(
                            id: "task-health-meal-list",
                            projectID: "health-meals",
                            title: "Write one meal idea for tonight",
                            reason: "One concrete choice beats carrying the whole problem around.",
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
                            reason: "One small prep step lowers the cost of the whole meal later.",
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
                    name: "Recovery & calm",
                    summary: "Make rest and reset visible instead of optional.",
                    aliases: ["recovery", "calm", "rest", "reset"],
                    tasks: [
                        task(
                            id: "task-health-recovery-reset",
                            projectID: "health-recovery",
                            title: "Sit down for a 2-minute reset",
                            reason: "A tiny pause is enough to interrupt the spiral.",
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
                            reason: "A short reset can change the whole feel of the next hour.",
                            minutes: 5,
                            type: .upcoming,
                            energy: .low,
                            category: .health,
                            context: .outdoor
                        ),
                        task(
                            id: "task-health-recovery-breaths",
                            projectID: "health-recovery",
                            title: "Fill your glass and take 5 breaths",
                            reason: "It is concrete, finite, and calming.",
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
                    summary: "A light self-renewal loop for people who need mental reset, not just productivity.",
                    aliases: ["read", "reflect", "renewal"],
                    tasks: [
                        task(
                            id: "task-health-reflect-page",
                            projectID: "health-reflect",
                            title: "Read 1 page",
                            reason: "A tiny reading dose is easier to keep than waiting for the perfect block.",
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
                            title: "Save one idea you do not want to lose",
                            reason: "Capturing the idea is enough for today.",
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
            subtitle: "Keep important people from slipping into the background",
            icon: "person.2.fill",
            colorHex: "#A53E6D",
            aliases: ["relationships", "friends", "family", "social"],
            projects: [
                project(
                    id: "relationships-partner-family",
                    lifeAreaID: "relationships",
                    name: "Partner / family",
                    summary: "Keep close relationships visible in a low-pressure way.",
                    aliases: ["partner", "family", "home people"],
                    tasks: [
                        task(
                            id: "task-relationships-family-text",
                            projectID: "relationships-partner-family",
                            title: "Send one check-in text",
                            reason: "One small touch counts.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-calendar",
                            projectID: "relationships-partner-family",
                            title: "Add one family date to calendar",
                            reason: "Putting it on the calendar keeps it real.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-family-question",
                            projectID: "relationships-partner-family",
                            title: "Write one thing you want to ask about",
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
                    summary: "Keep friendship maintenance light and visible.",
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
                            title: "Suggest one plan to a friend",
                            reason: "A specific suggestion is easier to act on than a vague intention.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .social,
                            context: .phone
                        ),
                        task(
                            id: "task-relationships-friends-list",
                            projectID: "relationships-friends",
                            title: "Write down one friend to check in with",
                            reason: "One name gives you a clear next move.",
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
                    summary: "Turn vague social intentions into one small plan.",
                    aliases: ["social plans", "weekend plans", "hangouts"],
                    tasks: [
                        task(
                            id: "task-relationships-social-idea",
                            projectID: "relationships-social-plans",
                            title: "Write one idea for the weekend",
                            reason: "One idea is enough to get plans unstuck.",
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
                            reason: "The send matters more than the perfect wording.",
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
            subtitle: "Study, practice, and keep growth visible without turning it into homework",
            icon: "book.fill",
            colorHex: "#9E5F0A",
            aliases: ["learning", "growth", "study", "practice"],
            projects: [
                project(
                    id: "learning-read",
                    lifeAreaID: "learning-growth",
                    name: "Read and capture",
                    summary: "Turn a small reading moment into something retained.",
                    aliases: ["read", "reading", "capture"],
                    tasks: [
                        task(
                            id: "task-learning-read-page",
                            projectID: "learning-read",
                            title: "Open the book and read 1 page",
                            reason: "The commitment is tiny, but it still counts as re-entry.",
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
                            reason: "One sentence closes the loop on previous effort.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .learning,
                            context: .anywhere
                        ),
                        task(
                            id: "task-learning-read-save",
                            projectID: "learning-read",
                            title: "Save one idea you want to revisit",
                            reason: "Capturing the idea counts as progress.",
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
                    summary: "Short, bounded study bursts.",
                    aliases: ["study session", "course", "class"],
                    tasks: [
                        task(
                            id: "task-learning-study-open",
                            projectID: "learning-study",
                            title: "Open the study doc",
                            reason: "Opening the material is often the actual activation barrier.",
                            minutes: 1,
                            type: .upcoming,
                            energy: .low,
                            category: .learning,
                            context: .computer
                        ),
                        task(
                            id: "task-learning-study-question",
                            projectID: "learning-study",
                            title: "Write one question you want to answer",
                            reason: "A question gives the study block shape immediately.",
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
                    summary: "Build repetition without needing a huge block of time.",
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
                            title: "Write the next tiny thing to practice",
                            reason: "The next rep is easier when it is already named.",
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
            subtitle: "Make room for hobbies, play, and expression",
            icon: "paintpalette.fill",
            colorHex: "#D97706",
            aliases: ["creativity", "fun", "hobby", "creative"],
            projects: [
                project(
                    id: "creativity-writing",
                    lifeAreaID: "creativity-fun",
                    name: "Personal writing",
                    summary: "Keep creative output warm with tiny starts.",
                    aliases: ["writing", "journal", "notes"],
                    tasks: [
                        task(
                            id: "task-creativity-writing-lines",
                            projectID: "creativity-writing",
                            title: "Write 2 lines",
                            reason: "A tiny opening sentence is enough for re-entry.",
                            minutes: 2,
                            type: .evening,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-writing-title",
                            projectID: "creativity-writing",
                            title: "Open the note and title the idea",
                            reason: "Naming the idea lowers the cost of coming back.",
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
                    summary: "Keep the hobby visible without demanding a full session.",
                    aliases: ["hobby", "practice", "creative practice"],
                    tasks: [
                        task(
                            id: "task-creativity-hobby-materials",
                            projectID: "creativity-hobby",
                            title: "Put the materials where you can reach them",
                            reason: "Reducing setup friction makes the hobby more likely to happen.",
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
                            reason: "A short block keeps the loop alive.",
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
                    summary: "Capture fun before the week consumes it.",
                    aliases: ["weekend", "fun plans", "ideas"],
                    tasks: [
                        task(
                            id: "task-creativity-weekend-idea",
                            projectID: "creativity-weekend",
                            title: "Write one fun idea for this week",
                            reason: "A single idea gives the week more shape.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .creative,
                            context: .anywhere
                        ),
                        task(
                            id: "task-creativity-weekend-save",
                            projectID: "creativity-weekend",
                            title: "Save one place or event to try",
                            reason: "Saving it now keeps it from dissolving.",
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
            subtitle: "Give money its own lane when you want deeper visibility",
            icon: "dollarsign.circle.fill",
            colorHex: "#2E8B57",
            aliases: ["finance", "finances", "budget"],
            projects: [
                project(
                    id: "money-bills",
                    lifeAreaID: "money",
                    name: "Bills this week",
                    summary: "Remove uncertainty before it starts compounding.",
                    aliases: ["bills", "payments", "due dates"],
                    tasks: [
                        task(
                            id: "task-money-standalone-bills-date",
                            projectID: "money-bills",
                            title: "Open one bill and check the due date",
                            reason: "Knowing the date lowers dread immediately.",
                            minutes: 2,
                            type: .upcoming,
                            energy: .low,
                            category: .finance,
                            context: .computer
                        ),
                        task(
                            id: "task-money-standalone-reminder",
                            projectID: "money-bills",
                            title: "Add one due date to reminders",
                            reason: "One reminder removes the need to hold it in memory.",
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
                    summary: "Lightweight money awareness without a full planning session.",
                    aliases: ["budget", "spending", "plan"],
                    tasks: [
                        task(
                            id: "task-money-budget-receipt",
                            projectID: "money-budget",
                            title: "Move one receipt into one place",
                            reason: "Organizing one input is easier than fixing the whole system.",
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
                            reason: "One quick review reduces uncertainty fast.",
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
                    summary: "Small admin that prevents surprise problems later.",
                    aliases: ["financial errands", "bank", "paperwork"],
                    tasks: [
                        task(
                            id: "task-money-errands-note",
                            projectID: "money-errands",
                            title: "Write the one money errand you need",
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
                            title: "Check the hours for one money errand",
                            reason: "Knowing the constraint makes it easier to finish.",
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
            reason: "Deciding before you stop makes tomorrow easier to begin.",
            cadence: .daily(hour: 17, minute: 30),
            symbol: "briefcase.fill",
            categoryKey: "work",
            notes: "Keep it to one specific next step.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-work-must-move",
            lifeAreaID: "work-career",
            projectID: "work-ship",
            title: "End the day by naming one \"must move\" item",
            reason: "One named item keeps tomorrow from starting blank.",
            cadence: .daily(hour: 17, minute: 45),
            symbol: "flag.fill",
            categoryKey: "work",
            notes: "Pick one thing, not a full list.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-career-followups",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Check follow-ups every weekday",
            reason: "A light weekday sweep keeps important threads from disappearing.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 16, minute: 0),
            symbol: "tray.full.fill",
            categoryKey: "work",
            notes: "You are maintaining visibility, not clearing everything.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-work-waiting-on",
            lifeAreaID: "work-career",
            projectID: "work-followups",
            title: "Review waiting-on items before signing off",
            reason: "One short pass keeps important loose ends visible.",
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
            reason: "Short resets lower the cost of coming back to your space later.",
            cadence: .daily(hour: 20, minute: 0),
            symbol: "house.fill",
            categoryKey: "life",
            notes: "Stop after two minutes even if more is possible.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-life-surface",
            lifeAreaID: "life-admin",
            projectID: "life-home-reset",
            title: "Reset one visible surface every evening",
            reason: "One visible patch of calm is easier to sustain than a full cleanup.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "sparkles",
            categoryKey: "life",
            notes: "Pick just one surface.",
            recommendedProfiles: [.finishing]
        ),
        positiveHabit(
            id: "habit-life-appointments-check",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Check appointments twice a week",
            reason: "A light review is enough to keep appointments from surprising you.",
            cadence: .weekly(daysOfWeek: [2, 5], hour: 18, minute: 0),
            symbol: "calendar.badge.clock",
            categoryKey: "life",
            notes: "Check what is coming, not everything at once.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-life-paperwork-capture",
            lifeAreaID: "life-admin",
            projectID: "life-appointments-paperwork",
            title: "Put paperwork in one capture place",
            reason: "One place lowers the mental cost of admin.",
            cadence: .weekly(daysOfWeek: [2, 4, 6], hour: 18, minute: 30),
            symbol: "tray.and.arrow.down.fill",
            categoryKey: "life",
            notes: "Do not sort it yet.",
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
            reason: "One weekly glance removes uncertainty without turning into a finance project.",
            cadence: .weekly(daysOfWeek: [6], hour: 11, minute: 0),
            symbol: "creditcard.fill",
            categoryKey: "life",
            notes: "This is about awareness, not perfection.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-money-check",
            lifeAreaID: "life-admin",
            projectID: "life-bills-money",
            title: "Weekly account glance",
            reason: "A short weekly glance is easier to keep than a full budget session.",
            cadence: .weekly(daysOfWeek: [6], hour: 12, minute: 0),
            symbol: "dollarsign.circle.fill",
            categoryKey: "life",
            notes: "You are checking in, not judging.",
            recommendedProfiles: [.choosing, .remembering]
        ),
        positiveHabit(
            id: "habit-life-digital-cleanup",
            lifeAreaID: "life-admin",
            projectID: "life-digital-reset",
            title: "5-minute inbox cleanup once a week",
            reason: "One short cleanup keeps digital clutter from silently growing.",
            cadence: .weekly(daysOfWeek: [7], hour: 18, minute: 0),
            symbol: "envelope.badge.fill",
            categoryKey: "life",
            notes: "Five minutes is enough.",
            recommendedProfiles: [.overwhelmed]
        ),

        positiveHabit(
            id: "habit-health-water",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Drink water after you wake up",
            reason: "It is easy to remember, takes seconds, and creates a clean start signal.",
            cadence: .daily(hour: 8, minute: 0),
            symbol: "drop.fill",
            categoryKey: "health",
            notes: "Use a tiny win that helps the next healthy choice happen.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-move-five",
            lifeAreaID: "health-self",
            projectID: "health-move",
            title: "Move for 5 minutes each morning",
            reason: "A tiny movement block is easier to keep than a full routine.",
            cadence: .daily(hour: 8, minute: 30),
            symbol: "figure.walk",
            categoryKey: "health",
            notes: "Five minutes is enough.",
            recommendedProfiles: [.starting]
        ),
        positiveHabit(
            id: "habit-health-charge",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Put your phone on the charger before bed",
            reason: "A visible bedtime cue is easier to keep than a full evening routine.",
            cadence: .daily(hour: 21, minute: 30),
            symbol: "bed.double.fill",
            categoryKey: "health",
            notes: "Make the stop signal obvious.",
            recommendedProfiles: [.remembering]
        ),
        negativeHabit(
            id: "habit-health-no-phone-bed",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Keep your phone out of bed",
            reason: "This supports better wind-down without asking for a perfect night.",
            cadence: .daily(hour: 22, minute: 0),
            symbol: "moon.zzz.fill",
            categoryKey: "health",
            notes: "Recovery matters more than streak perfection.",
            recommendedProfiles: [.remembering, .overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-same-wind-down",
            lifeAreaID: "health-self",
            projectID: "health-sleep",
            title: "Start wind-down at the same time each night",
            reason: "A consistent cue makes stopping easier later.",
            cadence: .daily(hour: 21, minute: 0),
            symbol: "moon.stars.fill",
            categoryKey: "health",
            notes: "It does not have to be perfect.",
            recommendedProfiles: [.remembering]
        ),
        positiveHabit(
            id: "habit-health-lunch",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Decide lunch before noon",
            reason: "One small decision lowers food friction before it gets loud.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 11, minute: 0),
            symbol: "fork.knife",
            categoryKey: "health",
            notes: "A rough decision counts.",
            recommendedProfiles: [.choosing]
        ),
        positiveHabit(
            id: "habit-health-snack",
            lifeAreaID: "health-self",
            projectID: "health-meals",
            title: "Eat one protein-first snack daily",
            reason: "A small reliable snack lowers the cost of better food choices.",
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
            title: "Do a 2-minute reset after work",
            reason: "A short reset creates recovery without demanding a full routine.",
            cadence: .weekly(daysOfWeek: [2, 3, 4, 5, 6], hour: 18, minute: 0),
            symbol: "figure.mind.and.body",
            categoryKey: "health",
            notes: "Two minutes is enough to count.",
            recommendedProfiles: [.overwhelmed]
        ),
        positiveHabit(
            id: "habit-health-check-energy",
            lifeAreaID: "health-self",
            projectID: "health-recovery",
            title: "Check energy before taking on more",
            reason: "A quick check helps you stop borrowing from later.",
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
            reason: "A tiny daily dose is easier to keep than waiting for a deep session.",
            cadence: .daily(hour: 20, minute: 30),
            symbol: "book.fill",
            categoryKey: "health",
            notes: "Stop after one page if that is all you have today.",
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
            title: "Check in with one person each week",
            reason: "One short check-in keeps relationships from drifting into the background.",
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
            title: "Make something for 10 minutes twice a week",
            reason: "A short playful block is easier to keep than waiting for a perfect creative window.",
            cadence: .weekly(daysOfWeek: [3, 7], hour: 19, minute: 0),
            symbol: "paintbrush.pointed.fill",
            categoryKey: "creativity",
            notes: "Stop at ten minutes if you want.",
            recommendedProfiles: []
        ),
        positiveHabit(
            id: "habit-money-glance",
            lifeAreaID: "money",
            projectID: "money-budget",
            title: "Weekly account glance",
            reason: "A short check-in keeps money visible without turning it into a project.",
            cadence: .weekly(daysOfWeek: [7], hour: 12, minute: 0),
            symbol: "banknote.fill",
            categoryKey: "money",
            notes: "Awareness beats avoidance.",
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
        legacyTaskIDMap[id] ?? id
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
            title: "Open this project and pick one next step",
            reason: "A tiny orienting action still counts as motion.",
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
