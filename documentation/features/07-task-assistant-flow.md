# Task Assistant Flow Documentation
**CatCareCalendar - Conversational task actions**

---

## Goal

The Task Assistant should make common task actions conversational without replacing the Tasks tab or duplicating task business logic.

## Entry Flow

- Assistant is a top-level tab alongside Home, Tasks, and More.
- App routing and the `catcarecalendar:///assistant` deep link can select the Assistant tab directly.
- The tab opens to a calm welcome screen with a short explanation, up to three Assistant suggestions, and a Start Chat action.
- The message composer is reserved for the focused chat destination so the welcome screen remains glanceable.
- Selecting Start Chat opens an empty focused conversation.
- Selecting an Assistant suggestion opens the same conversation and presents the existing confirmation flow for that task.

## Focused Conversation

- Focused chat hides the tab bar to give the message list and composer the full bottom safe area.
- A leading X button ends the chat: it clears messages, the draft, and any pending confirmation/clarification/completion request, then returns to the Assistant welcome screen and restores the tab bar.
- The welcome action is always Start Chat — chat state is never resumed across a dismissal.
- Selecting another Assistant suggestion after ending chat starts a fresh conversation and presents its confirmation.
- Dictation stops when chat is left, along with the rest of the conversation state.
- Cloud interpretation consent is requested only after the user enters focused chat.

## Task Actions

- Opening, postponing, and completing tasks must continue through the existing interpreter and task-action services.
- Ambiguous requests use the existing clarification card.
- Destructive or state-changing requests require confirmation.
- Detailed completion requirements continue to use the standard task-completion flow.
- Opening a task routes to the Tasks tab and its existing editor.

## UX And Accessibility

- Keep the Task Assistant navigation title on both welcome and focused chat screens.
- The tab bar icon is a system symbol (`cat.circle.fill`); the welcome screen, in-chat empty state, and typing indicator share the `TaskAssistantMascotView` illustration so the character reads consistently across those larger surfaces — the tab bar itself can't host a custom SwiftUI illustration since `Tab(systemImage:)` requires an SF Symbol name.
- Preserve Dynamic Type, VoiceOver labels, keyboard-safe composer placement, and Reduce Motion behavior.
- The focused chat transition should use standard NavigationStack behavior; supplementary composer motion should become opacity-only when Reduce Motion is enabled.
