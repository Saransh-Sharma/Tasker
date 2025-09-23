# ChatHostViewController

<cite>
**Referenced Files in This Document**   
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift)
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift)
- [ConversationView.swift](file://To Do List/LLM/Views/Chat/ConversationView.swift)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [UI State Management](#ui-state-management)
7. [Integration with LLMDataController](#integration-with-llmdatacontroller)
8. [User Interaction and Input Handling](#user-interaction-and-input-handling)
9. [Response Rendering and Message Display](#response-rendering-and-message-display)
10. [Error Handling and Edge Cases](#error-handling-and-edge-cases)
11. [Performance and Memory Considerations](#performance-and-memory-considerations)
12. [Customization Options](#customization-options)
13. [Troubleshooting Guide](#troubleshooting-guide)

## Introduction

The **ChatHostViewController** serves as the primary interface for AI-powered task assistance within the Tasker application. It functions as a UIKit view controller that hosts a SwiftUI-based chat interface, enabling users to interact with a local large language model (LLM) for task management support. This component orchestrates the presentation of either an onboarding flow (when no LLM model is installed) or the main chat UI, depending on the user's setup state.

The controller manages navigation, user input delegation, and lifecycle events while embedding SwiftUI views through a `UIHostingController`. It integrates tightly with the LLM module's data layer via SwiftData and coordinates with the `LLMEvaluator` for message processing and response generation. The design follows a hybrid UIKit-SwiftUI pattern, leveraging the strengths of both frameworks to deliver a responsive and feature-rich conversational experience.

**Section sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)

## Project Structure

The LLM module within Tasker is organized under the `To Do List/LLM/` directory, following a modular structure that separates concerns across different subdirectories:

- **Models**: Contains data models, state controllers, and business logic (e.g., `LLMDataController.swift`, `LLMEvaluator.swift`)
- **Views/Chat**: Houses SwiftUI views related to the chat interface (`ChatView.swift`, `ConversationView.swift`)
- **Views/Onboarding**: Manages model installation guidance and setup flows
- **Extensions**: Provides SwiftUI view modifiers and utility extensions

This separation enables maintainable code with clear responsibilities, where `ChatHostViewController` acts as the bridge between UIKit navigation and the SwiftUI-driven LLM interface.

```mermaid
graph TB
subgraph "LLM Module"
ChatHostViewController --> ChatContainerView
ChatContainerView --> OnboardingView
ChatContainerView --> ChatView
ChatView --> ConversationView
ChatView --> ChatsListView
ChatHostViewController --> LLMDataController
ChatHostViewController --> LLMEvaluator
end
```

**Diagram sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift#L1-L16)

## Core Components

The core functionality of the chat system revolves around several key components:

- **ChatHostViewController**: The UIKit host controller that initializes and presents the SwiftUI chat interface.
- **ChatContainerView**: A SwiftUI container that decides whether to show onboarding or the main chat based on model installation status.
- **ChatView**: The primary chat interface responsible for input handling, message submission, and thread management.
- **ConversationView**: Renders individual messages in a thread using Markdown formatting.
- **LLMDataController**: Singleton providing shared SwiftData persistence for chat threads and messages.
- **LLMEvaluator**: Handles LLM model loading, prompt generation, and streaming response evaluation.

These components work together to create a seamless AI interaction experience within the Tasker app.

**Section sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift#L1-L16)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)

## Architecture Overview

The architecture follows a layered pattern with clear separation between presentation, state management, and data persistence:

```mermaid
graph TD
A[UIKit Navigation] --> B[ChatHostViewController]
B --> C[UIHostingController]
C --> D[SwiftUI Views]
D --> E[LLMEvaluator]
D --> F[LLMDataController]
E --> G[MLX/MLXLLM Frameworks]
F --> H[SwiftData Persistent Store]
D --> I[AppManager]
style A fill:#f9f,stroke:#333
style B fill:#bbf,stroke:#333
style C fill:#bbf,stroke:#333
style D fill:#bbf,stroke:#333
style E fill:#f96,stroke:#333
style F fill:#f96,stroke:#333
style G fill:#6f9,stroke:#333
style H fill:#6f9,stroke:#333
style I fill:#f96,stroke:#333
```

**Diagram sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift#L1-L16)

## Detailed Component Analysis

### ChatHostViewController Analysis

The `ChatHostViewController` is responsible for embedding the SwiftUI-based LLM interface within a UIKit navigation hierarchy. It sets up the hosting controller and configures the navigation bar using FluentUI.

#### Class Diagram

```mermaid
classDiagram
class ChatHostViewController {
-appManager : AppManager
-llmEvaluator : LLMEvaluator
-container : ModelContainer
-hostingController : UIHostingController<AnyView>
+viewDidLoad()
-setupFluentNavigationBar()
-onBackTapped()
-onHistoryTapped()
}
class UIHostingController {
+rootView : AnyView
+view : UIView
}
class ChatContainerView {
@EnvironmentObject appManager : AppManager
@Environment llm : LLMEvaluator
@State showOnboarding : Bool
@State currentThread : Thread?
}
ChatHostViewController --> UIHostingController : "embeds"
ChatHostViewController --> ChatContainerView : "initializes"
ChatHostViewController --> LLMDataController : "uses shared container"
ChatHostViewController --> LLMEvaluator : "passes to environment"
```

**Diagram sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)

**Section sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)

### ChatView Analysis

The `ChatView` struct manages the main chat interface, handling user input, message generation, and thread lifecycle.

#### Sequence Diagram

```mermaid
sequenceDiagram
participant User
participant ChatView
participant LLMEvaluator
participant LLMDataController
participant ModelContext
User->>ChatView : Types message and taps send
ChatView->>ChatView : validate input and parse slash commands
alt No current thread
ChatView->>ModelContext : create new Thread
ModelContext-->>ChatView : return Thread
end
ChatView->>ModelContext : insert Message(role : .user)
ChatView->>LLMEvaluator : generate(modelName, thread, systemPrompt)
LLMEvaluator->>LLMEvaluator : load model if needed
LLMEvaluator->>MLXLLM : stream generate tokens
loop Token streaming
MLXLLM-->>LLMEvaluator : emit tokens
LLMEvaluator->>ChatView : update output every N tokens
ChatView->>ConversationView : display partial response
end
LLMEvaluator-->>ChatView : return final output
ChatView->>ModelContext : insert Message(role : .assistant)
```

**Diagram sources**
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)

**Section sources**
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)

## UI State Management

The chat interface maintains several UI states during LLM interactions:

- **Idle**: Ready for user input, generate button enabled when prompt is non-empty
- **Thinking**: LLM is generating response, stop button displayed, input disabled
- **Loading Model**: Progress indicator shown during model download
- **Onboarding**: Model installation guide displayed when no models are installed
- **Chat History Visible**: Sheet presenting list of saved threads (on iPhone)

State transitions are managed through bindings and environment objects:

- `@State private var isPromptFocused` controls keyboard visibility
- `@State private var showChats` controls chat history sheet presentation
- `@State private var showModelPicker` manages model selection UI
- `@Environment(LLMEvaluator.self) var llm` provides access to `running`, `cancelled`, and `output` states

The `ConversationView` also tracks scrolling behavior to prevent auto-scroll interruption when users manually scroll through long conversations.

**Section sources**
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [ConversationView.swift](file://To Do List/LLM/Views/Chat/ConversationView.swift#L1-L239)

## Integration with LLMDataController

The `ChatHostViewController` integrates with `LLMDataController` to provide a shared persistent SwiftData container for all LLM-related data.

### Data Flow

```mermaid
flowchart TD
A[ChatHostViewController] --> B[LLMDataController.shared]
B --> C[SwiftData Container]
C --> D[(SQLite Database)]
A --> E[ChatContainerView]
E --> F[ChatView]
F --> G[ModelContext]
G --> C
style A fill:#bbf,stroke:#333
style B fill:#f96,stroke:#333
style C fill:#6f9,stroke:#333
style D fill:#6f9,stroke:#333
style E fill:#bbf,stroke:#333
style F fill:#bbf,stroke:#333
style G fill:#f96,stroke:#333
```

The `LLMDataController` is implemented as a singleton enum that creates a `ModelContainer` configured with CloudKit disabled, ensuring local-only persistence:

```swift
@MainActor
enum LLMDataController {
    static let shared: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: Thread.self, Message.self, configurations: config)
        } catch {
            fatalError("Unable to create SwiftData container...")
        }
    }()
}
```

This container is passed to the SwiftUI view hierarchy via `.modelContainer(container)`.

**Diagram sources**
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift#L1-L16)
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)

**Section sources**
- [LLMDataController.swift](file://To Do List/LLM/Models/LLMDataController.swift#L1-L16)

## User Interaction and Input Handling

User interactions are handled through a combination of SwiftUI bindings and UIKit navigation controls.

### Input Processing Workflow

```mermaid
flowchart TD
Start([User types message]) --> SlashCheck{"Starts with /?"}
SlashCheck --> |Yes| ParseCommand["Parse slash command"]
ParseCommand --> CommandSwitch{Command Type}
CommandSwitch --> |/today, /tomorrow| Summary[Build task summary]
CommandSwitch --> |/project| ProjectQuery["Match project by name"]
CommandSwitch --> |/clear| ClearThread["Delete current thread"]
CommandSwitch --> |None| NormalFlow["Proceed with normal generation"]
SlashCheck --> |No| NormalFlow
NormalFlow --> EnsureThread["Ensure thread exists"]
EnsureThread --> SaveUserMessage["Save user message to SwiftData"]
SaveUserMessage --> CallLLM["Call LLMEvaluator.generate()"]
CallLLM --> StreamResponse["Stream response tokens"]
StreamResponse --> UpdateUI["Update UI incrementally"]
UpdateUI --> SaveAssistantMessage["Save final response"]
```

The `generate()` function in `ChatView` handles all input processing, including:
- Slash command parsing (`/today`, `/week`, `/project`, `/clear`)
- Dynamic system prompt construction with task context
- Thread creation and message persistence
- Haptic feedback on message send

**Section sources**
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)

## Response Rendering and Message Display

Responses are rendered using `ConversationView` and `MessageView`, which support Markdown formatting and thinking visualization.

### Message Rendering Logic

```mermaid
classDiagram
class MessageView {
+message : Message
+isThinking : Bool
+collapsed : Bool
+processThinkingContent(content) (thinking, afterThink)
+body : some View
}
class ConversationView {
+thread : Thread
+generatingThreadID : UUID?
+scrollID : String?
+scrollInterrupted : Bool
+body : some View
}
ConversationView --> MessageView : "displays each"
MessageView --> MarkdownUI : "uses for rendering"
```

Key features:
- **Thinking visualization**: Content between `<think>` and `</think>` tags is displayed in a collapsible section
- **Streaming display**: Partial responses are shown as tokens arrive, updating every 4 tokens for performance
- **Markdown support**: Both user and assistant messages are rendered with `MarkdownUI`
- **Auto-scrolling**: ScrollView automatically scrolls to bottom unless user has manually scrolled away

The `MessageView` processes thinking content by splitting the message into pre-think, thinking, and post-think segments for appropriate rendering.

**Diagram sources**
- [ConversationView.swift](file://To Do List/LLM/Views/Chat/ConversationView.swift#L1-L239)

**Section sources**
- [ConversationView.swift](file://To Do List/LLM/Views/Chat/ConversationView.swift#L1-L239)

## Error Handling and Edge Cases

The system handles several error conditions and edge cases:

- **Model not found**: `LLMEvaluator` throws `modelNotFound` error, displayed in chat
- **Empty prompts**: Generate button is disabled when prompt is empty
- **Network failures**: Model download progress shows percentage; failures result in error message
- **Context injection**: Task/project context is added only once per thread to prevent prompt bloat
- **Thread management**: New threads are created automatically when sending first message
- **Cancellation**: Users can stop generation with the stop button

Error messages are displayed directly in the chat interface as assistant messages, maintaining context within the conversation flow.

**Section sources**
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)

## Performance and Memory Considerations

The implementation includes several performance optimizations:

- **Throttled UI updates**: LLM output is updated every 4 tokens instead of every token (~15% performance improvement)
- **Shared SwiftData container**: Single persistent container reduces memory overhead
- **Lazy model loading**: Models are loaded only when needed and cached
- **Efficient scrolling**: `ScrollViewReader` with scroll interruption detection prevents unnecessary updates
- **Context deduplication**: Task context is injected only once per thread to keep prompts small

Memory management during prolonged conversations is handled by SwiftData's persistence, which stores messages to disk while keeping active threads in memory.

**Section sources**
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)

## Customization Options

The chat interface can be customized through several mechanisms:

- **FluentUI navigation bar**: Customizable title style, color, and button placement
- **Platform-specific styling**: Different padding, corner radius, and layout for iOS, visionOS, and macOS
- **Haptic feedback**: Configurable through `AppManager.playHaptic()`
- **Model selection**: Users can switch between available models via the model picker
- **Theme adaptation**: Uses system colors and platform-specific background colors

Appearance customization can be achieved by modifying:
- `platformBackgroundColor` in `ChatView` and `MessageView`
- Navigation bar styling in `setupFluentNavigationBar()`
- Corner radii and padding values for input fields and message bubbles

**Section sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)

## Troubleshooting Guide

Common issues and their solutions:

**Issue**: Chat interface shows onboarding screen unexpectedly  
**Solution**: Ensure at least one LLM model is installed via the settings menu

**Issue**: Messages not saving between app launches  
**Solution**: Verify `LLMDataController` is using persistent storage (should be automatic with current configuration)

**Issue**: Slow response times or token generation  
**Solution**: Check device performance; consider using smaller models for better speed

**Issue**: Thinking visualization not collapsing/expanding  
**Solution**: Verify `collapsed` state binding is properly connected in `MessageView`

**Issue**: Model download fails repeatedly  
**Solution**: Check network connection and available storage space

**Issue**: Chat history not appearing on iPhone  
**Solution**: Verify `showChats` binding is connected to the history button action

**Section sources**
- [ChatHostViewController.swift](file://To Do List/LLM/ChatHostViewController.swift#L1-L141)
- [ChatView.swift](file://To Do List/LLM/Views/Chat/ChatView.swift#L1-L441)
- [LLMEvaluator.swift](file://To Do List/LLM/Models/LLMEvaluator.swift#L1-L166)