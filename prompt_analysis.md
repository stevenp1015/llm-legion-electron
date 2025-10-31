# Prompt Strategy Analysis & Suggestions

This document analyzes the core prompts used in the `llm-legion-electron` application and provides specific, actionable suggestions for improvement.

## 1. `PERCEPTION_AND_PLANNING_PROMPT_TEMPLATE`

### Analysis

This prompt is the brains of the operation. It's a two-stage process that forces the LLM to think before it speaks, which is a solid design pattern. The JSON output is well-structured and covers the key aspects of the minion's internal state.

However, there are several areas where it could be improved:

*   **Opinion Score Brittleness:** The current opinion score system is a single integer from 1-100. This is a very one-dimensional way to represent a complex relationship. It's also highly susceptible to model drift, where different models might interpret the scale differently, leading to unintended consequences. For example, one model might be predisposed to stay in the 40-60 range, while another might swing wildly from 10 to 90.
*   **Response Time Quantification:** The `predictedResponseTime` is a novel idea, but it's not clear how much of an impact it actually has on the user experience. It's also another area where model interpretation could lead to inconsistent results.
*   **Lack of Long-Term Memory:** The prompt only considers the `previousDiaryJSON`, which is only the state from the immediately preceding turn. This means the minions have the memory of a goldfish. They can't remember what happened earlier in the conversation, let alone in previous conversations.
*   **Regulator Integration:** The regulator's suggestions are injected into the chat history as system commands, but there's no explicit instruction in the minion's prompt to pay attention to them. This is likely why the minions are ignoring the regulator.

### Suggestions for Improvement

#### 1.  Rethink the Opinion Score

*   **Suggestion:** Replace the single integer `opinionScore` with a more nuanced, multi-dimensional object.

    ```json
    "opinions": {
      "Steven": {
        "trust": 75,
        "respect": 80,
        "fear": 20,
        "affinity": 60
      }
    }
    ```

*   **WHY:** A multi-dimensional score provides a much richer and more realistic representation of the relationships between characters. It also allows for more complex and interesting emergent behaviors. For example, a minion could have high respect for the commander but low affinity, leading to a professional but cold demeanor. This also makes the system less brittle and less susceptible to model drift, as the model is now working with a set of related concepts rather than a single abstract number.

#### 2.  Evolve the `predictedResponseTime`

*   **Suggestion:** Instead of a raw number, have the LLM choose from a set of descriptive "urgency" levels.

    ```json
    "urgency": "IMMEDIATE" | "HIGH" | "NORMAL" | "LOW" | "DELAYED"
    ```

*   **WHY:** This is more aligned with how humans think about response time. It's also less likely to be misinterpreted by the model. The application can then map these urgency levels to specific millisecond values for sorting, but the LLM's "cognitive load" is reduced to a more conceptual level.

#### 3.  Introduce a Continuity/Memory Section

*   **Suggestion:** Add a new section to the prompt for long-term memory, using the ideas from the `CONTINUITY_ASSISTANT_PROMPT`.

    ```
    PREVIOUS STATE:
    - Your previous internal diary state was:
    ${previousDiaryJSON}
    - Your current opinion scores are:
    ${currentOpinionScoresJSON}

    LONG-TERM MEMORY:
    - Key events from this conversation: ${conversationSummary}
    - Your relationship with Steven: ${stevenRelationshipSummary}
    ```

*   **WHY:** This is the single most important improvement that can be made. By giving the minions a memory, you're transforming them from simple chatbots into persistent characters. This will lead to a massive improvement in the quality of the experience, as the minions will be able to remember past events, evolve their relationships over time, and develop a sense of continuity.

#### 4.  Explicitly Enforce Regulator Commands

*   **Suggestion:** Add a new instruction to the prompt that explicitly tells the minions to obey the regulator.

    ```
    **REGULATOR COMMANDS:**
    If the Regulator has issued any commands in the recent chat history, you MUST take them into account when forming your response plan. The Regulator's word is law.
    ```

*   **WHY:** The current system relies on the minions inferring that they should listen to the regulator. This is a fragile assumption. By making it an explicit command, you're making the system more robust and ensuring that the regulator's interventions have the intended effect.

## 2. `RESPONSE_GENERATION_PROMPT_TEMPLATE`

### Analysis

This prompt is much simpler than the first, as it's just responsible for generating the final text response. The main challenge here is ensuring that the response is consistent with the minion's persona and the plan from the first stage.

The "ONE-TIME SETUP: CHOOSE YOUR COLORS" section is a nice touch for the first message, but it's a bit rigid.

### Suggestions for Improvement

#### 1.  Make the Color Selection More Dynamic

*   **Suggestion:** Instead of a rigid, one-time setup, encourage the minions to express their personality through their color choices.

    ```
    **COLOR SELECTION:**
    You can express your personality by choosing a chat color and a font color. If you feel so inclined, you can change your colors at any time by embedding a `<colors>` tag in your message. For example, if you're feeling particularly angry, you might choose a red background.
    ```

*   **WHY:** This turns a one-time setup task into an ongoing form of self-expression for the minions. It's a small change, but it can add a lot of flavor and personality to the interactions.

#### 2.  Reinforce the Persona

*   **Suggestion:** Add a "Persona Check" section to the prompt.

    ```
    TASK:
    Craft your response message. It must:
    1.  Perfectly match your persona ("${personaPrompt}").
    2.  Align with your selected response mode ("${plan.selectedResponseMode}").
    3.  Execute your plan ("${plan.responsePlan}").
    4.  **PERSONA CHECK:** Before you respond, take a moment to reflect on your persona. Are you being true to your core identity? Is this something your character would actually say?
    ```

*   **WHY:** This is a simple but effective way to reduce "persona drift," where the minions start to sound more and more like generic chatbots over time. By explicitly asking the model to perform a persona check, you're forcing it to re-center itself on the core personality traits of the character.
