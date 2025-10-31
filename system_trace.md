# Full System Trace: llm-legion-electron

This document provides a detailed, sequential trace of the logic flow in the `llm-legion-electron` application, from user input to minion response.

## 1. Entry Point: `processMessageTurn` in `legionApiService.ts`

The entire process begins when a user sends a message, triggering the `processMessageTurn` function.

*   **Input:** The function receives a `HandleUserMessageParams` object, which contains:
    *   `channelId`: The ID of the channel where the message was sent.
    *   `triggeringMessage`: The `ChatMessageData` object for the user's message.
    *   Callbacks for handling various events (`onMinionResponse`, `onMinionResponseChunk`, etc.).

*   **Initial State Update:**
    1.  The user's message is immediately pushed into the `this.messages` array for the corresponding `channelId`.
    2.  The `messageCounter` for the channel is incremented.

*   **Minion Selection:**
    *   The function filters `this.minionConfigs` to get a list of minions that are members of the current channel and have the role of 'standard'.

*   **History Formatting:**
    *   A base chat history is created using `formatChatHistoryForLLM`. This initial history is the same for all minions and will be dynamically updated on a per-minion basis within the agentic loop.

*   **Initiating the Loop:**
    *   The core of the process is delegated to `_runAgentLoop`, which is called with the channel, the selected minions, the initial chat history, and the callbacks.

## 2. The Heart of the Beast: `_runAgentLoop`

This function is where the multi-turn, multi-actor logic resides. It's a `for` loop that can run up to `MAX_TURNS` (currently 10) to handle tool calls.

*   **Dynamic History:**
    *   A `Map` called `dynamicHistoryPerMinion` is created. This is crucial: it holds a separate, evolving chat history for each minion involved in the turn. This allows for minions to have private thoughts and tool call results that aren't seen by other minions.

*   **Turn 1: Perception and Planning**
    1.  **Minion Filtering:** In an autonomous chat, if a minion is already focused on a task (`activeToolMinionName`), only that minion is queried. Otherwise, all minions in the channel are queried.
    2.  **Perception Promises:** The function creates an array of promises by calling `_getPerceptionPlan` for each minion.
    3.  **`_getPerceptionPlan`:** This is the first of two major LLM calls.
        *   It selects an API key.
        *   It checks for rate limits.
        *   It fetches the available tools from the `mcpElectronService`.
        *   It constructs the `PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE` with the minion's persona, its last diary state, its opinion scores, the dynamic chat history, and the available tools.
        *   It calls `callLiteLLMApiForJson` to get a structured JSON response from the model.
        *   The result is a `PerceptionPlan` object (or an error).

*   **Processing Perception Results:**
    1.  The `perceptionResults` are collected. Any errors are reported as system messages.
    2.  The `lastDiaryState` and `opinionScores` for each minion are updated with the new plan.
    3.  The results are filtered to create a list of "actors"—minions that have chosen to 'SPEAK' or 'USE_TOOL'.
    4.  The actors are sorted by their `predictedResponseTime`, from fastest to slowest.

*   **Action Execution:**
    1.  The loop iterates through the sorted actors. In an autonomous chat, only the fastest actor is processed. In a user-driven chat, all actors are processed.
    2.  **If `action` is `USE_TOOL`:**
        *   If the chat is autonomous, the minion becomes the `activeToolMinionName`, focusing the loop on it for subsequent turns.
        *   If `speakWhileTooling` is present, that message is sent first.
        *   `_executeMcpTool` is called.
            *   **`_executeMcpTool`:**
                *   A `ChatMessageData` object is created to show the tool call in the UI.
                *   `mcpElectronService.callTool` sends an IPC message to the Electron main process, which then calls the actual tool.
                *   The tool's output is received from the main process.
                *   The `ChatMessageData` object is updated with the tool's output.
        *   The dynamic history for the minion that used the tool is updated with the tool call and its output. This is the key to the agentic loop—the minion will see the result of its action in the next turn.
    3.  **If `action` is `SPEAK`:**
        *   A temporary message is created to show the "is processing" indicator in the UI.
        *   The `RESPONSE_GENERATION_PROMPT_TEMPLATE` is constructed with the minion's persona, the dynamic chat history, and the `PerceptionPlan`.
        *   `runStreamingResponse` is called.

## 3. Generating the Response: `runStreamingResponse`

This function handles the second major LLM call and streams the response to the UI.

*   **API Call:**
    *   It calls `callLiteLLMAPIStream` from `geminiService.ts`.
    *   This function makes a POST request to the LiteLLM proxy with `stream: true`.

*   **Streaming:**
    *   The response is read as a stream of server-sent events.
    *   Each chunk of text is sent to the UI via the `onMinionResponseChunk` callback.

*   **Finalization:**
    *   When the stream is complete, the final message is constructed.
    *   If the minion included a `<colors>` tag in its first message, the `chatColor` and `fontColor` are extracted and saved to the minion's config.
    *   The final message object is sent to the UI via the `onMinionResponse` callback, and the message is saved to the `this.messages` array.
    *   The dynamic history for all minions is updated with the final message.

## 4. The Regulator: `_checkForRegulatorAction`

After the main agentic loop has completed, `_checkForRegulatorAction` is called.

*   **Trigger:**
    *   It checks if the `messageCounter` for the channel has reached the `regulationInterval` for any regulator minions in the channel.

*   **Execution:**
    *   If triggered, it generates a system message to indicate that the regulator is running.
    *   It calls `callLiteLLMApiForJson` with the `REGULATOR_SYSTEM_PROMPT` and the chat history.
    *   The response is a `RegulatorReport` object.

*   **Reporting:**
    *   The `RegulatorReport` is stringified and sent as a message from the regulator minion. This report is then parsed by `formatChatHistoryForLLM` on the next turn, and the `suggested_next_steps` are injected as system commands into the history for the other minions to see.
    *   The `messageCounter` for the channel is reset to 0.

This concludes the full trace of the agentic loop.
