# Latent Risk Analysis

This document identifies the top latent risks in the current `llm-legion-electron` architecture. These are issues that may not be causing major problems now, but have the potential to lead to catastrophic failures under specific conditions or in future versions.

## 1. State Management Brittleness

*   **The Risk:** The entire state of the application (minions, channels, messages) is held in memory in the `legionApiService`. This state is persisted to `electron-store`, but it's all loaded into memory at startup. As the number of minions, channels, and messages grows, this will lead to performance degradation and could eventually cause the application to crash. The "cleanup old messages" function is a band-aid, not a solution.

*   **Potential Failure Scenario:** A user has a long-running conversation with a large number of minions. The `messages` object grows to be several gigabytes in size. The application becomes slow and unresponsive, and eventually crashes with an out-of-memory error.

*   **Mitigation Strategy:**
    *   **Short-term:** Implement a more robust message pagination and lazy-loading system. Only load the messages that are currently visible in the UI.
    *   **Long-term:** Move the state management out of the renderer process and into the Electron main process. Use a proper database solution (like SQLite or IndexedDB) instead of a flat JSON file for storage. This would be a major architectural change, but it's the only way to ensure the long-term scalability of the application.

## 2. Unconstrained Persona Drift

*   **The Risk:** The minions' personalities are defined by a single `system_prompt_persona` string. While the prompts are well-designed, there's no mechanism to prevent "persona drift," where the minions' behavior gradually deviates from their intended personality over the course of a long conversation.

*   **Potential Failure Scenario:** A minion that is supposed to be "evil and aggressive" slowly becomes more and more friendly and helpful over the course of a long conversation, completely losing its original personality. The user's suspension of disbelief is shattered, and the experience is ruined.

*   **Mitigation Strategy:**
    *   **Implement a "Persona Core" System:** In addition to the main `system_prompt_persona`, define a set of core, immutable personality traits for each minion. These traits would be re-injected into the prompt on every turn, reminding the model of the minion's core identity.
    *   **Automated Persona Drift Detection:** The `Continuity Assistant` concept could be extended to include a persona drift detection module. This module would analyze the minion's responses over time and compare them to its core personality traits. If a significant deviation is detected, it could trigger a "persona reset" for the minion.

## 3. Tool Server Dependency Hell

*   **The Risk:** The tool system is tightly coupled to the `mcpElectronService`. The tools are defined as external processes that are managed by the Electron main process. This creates a number of potential points of failure.

*   **Potential Failure Scenario:** A user tries to run the application on a new machine, but they don't have the correct version of Python or the required dependencies for a specific tool. The tool server fails to start, but the application doesn't provide any clear feedback to the user. The user is left confused and frustrated.

*   **Mitigation Strategy:**
    *   **Containerize the Tools:** Package each tool server as a Docker container. This would ensure that the tool has all of its dependencies and that it runs in a consistent environment, regardless of the user's local machine setup.
    *   **Robust Tool Server Health Checks:** Implement a more robust system for checking the health of the tool servers. If a tool server fails to start or crashes, the application should provide a clear and actionable error message to the user.

## 4. Lack of a Centralized "World Model"

*   **The Risk:** Each minion has its own internal state (`lastDiaryState`, `opinionScores`), but there's no centralized "world model" that represents the shared understanding of the conversation. This can lead to inconsistencies and contradictions in the minions' behavior.

*   **Potential Failure Scenario:** Two minions have a conversation, but they come away with completely different understandings of what was said. In the next turn, they act on their conflicting interpretations, leading to a confusing and nonsensical interaction.

*   **Mitigation Strategy:**
    *   **Implement a Shared Context Object:** Create a new "shared context" object that is passed to all minions on every turn. This object would contain a summary of the key events, decisions, and agreements from the conversation so far. The `Continuity Assistant` could be responsible for generating and maintaining this shared context.
    *   **Consensus Mechanisms:** For important decisions, implement a simple consensus mechanism. For example, a minion could propose a course of action, and the other minions would have to vote on it before it's executed.

## 5. The "Single Point of Failure" API Service

*   **The Risk:** The entire application relies on a single, centralized `legionApiService`. If this service crashes or enters an inconsistent state, the entire application will fail.

*   **Potential Failure Scenario:** A rare, unhandled exception occurs in the `_runAgentLoop`. The `legionApiService` is now in a corrupted state. Subsequent calls to the service fail in unpredictable ways, and the user is forced to restart the application, losing their entire conversation history.

*   **Mitigation Strategy:**
    *   **Decentralize the State:** As mentioned in the first point, move the state management out of the renderer process and into the main process.
    *   **Implement a More Robust Error Handling and Recovery System:** The service should be designed to be more resilient to errors. For example, if an error occurs in the processing of a single turn, the service should be able to recover gracefully and continue processing the next turn, rather than crashing the entire application.
