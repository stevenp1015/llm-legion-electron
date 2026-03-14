export async function* runSwarmAnalysis(code: string, coreTenets?: string): AsyncGenerator<AgentMessage> {
    const tenetsPrefix = createTenetsPrefix(coreTenets);

    // --- PHASE 1: The Architect ---
    yield { id: 'swarm-init', role: 'Coordinator', content: 'Phase 1: Architectural Analysis. The Architect is mapping the territory...' };
    const architectSystemInstruction = `${tenetsPrefix}You are an expert software architect.`;
    const architectPrompt = `Your task is to analyze the provided codebase and create a high-level component and data flow diagram for the message streaming and rendering functionality. You must not propose any solutions.

Input Files: App.tsx, legionApiService.ts, messageStore.ts, ChatMessage.tsx, StreamingText.tsx.

Your Tasks:

1.  **Component Hierarchy**: Describe the parent-child relationships between these components. Who renders whom?
2.  **Data Flow**: Trace the lifecycle of a single streaming message chunk, starting from the callLiteLLMAPIStream call in legionApiService.ts. Detail every function call and state update until the text appears on screen. Explicitly describe the roles of processMessageChunk and _processChunkQueue.
3.  **State Management**: Identify all state related to messaging in messageStore.ts and describe which components subscribe to which pieces of state via the use... hooks.

Output: A concise markdown document titled 'Architectural Brief'. This document will serve as the foundational map for other specialists.

The codebase to analyze is below:
\`\`\`
${code}
\`\`\``;
    const architectResponse = await ai.models.generateContent({ model: MODEL_NAME, contents: architectPrompt, config: { systemInstruction: architectSystemInstruction } });
    const architecturalBrief = architectResponse.text;
    yield { id: 'architect-report', role: 'Architect', content: architecturalBrief };

    // --- PHASE 2: The Performance Engineer ---
    yield { id: 'swarm-perf-start', role: 'Coordinator', content: 'Phase 2: Performance Analysis. The Performance Engineer is identifying bottlenecks...' };
    const perfSystemInstruction = `${tenetsPrefix}You are a senior performance engineer specializing in React.`;
    const perfPrompt = `You have been given an 'Architectural Brief' (the output from Phase 1). Your task is to identify all potential performance bottlenecks and causes of inefficient rendering.

Input: The 'Architectural Brief' from the previous step.

Your Tasks:

1.  **Identify Re-render Triggers**: Based on the data flow map, list every event that causes a state change in messageStore.ts.
2.  **Analyze Render Cost**: For each state change, explain which components will re-render. Specifically, analyze the computational cost of re-rendering the <ReactMarkdown> component within StreamingText.tsx for every incoming text chunk.
3.  **Investigate Memoization Weaknesses**: The brief shows how props are passed to <ChatMessage>. Analyze the onDelete={() => ...} pattern and explain precisely why this practice defeats React.memo by creating unstable props.

Output: A 'Performance Hotspot Report' detailing each bottleneck and explaining the technical reason for the performance issue.

Here is the 'Architectural Brief':
---
${architecturalBrief}
---`;
    const perfResponse = await ai.models.generateContent({ model: MODEL_NAME, contents: perfPrompt, config: { systemInstruction: perfSystemInstruction } });
    const perfHotspotReport = perfResponse.text;
    yield { id: 'perf-report', role: 'Performance Engineer', content: perfHotspotReport };

    // --- PHASE 3: The Roundtable ---
    yield { id: 'swarm-roundtable-start', role: 'Coordinator', content: 'Phase 3: Roundtable. Three Senior Developers are proposing and critiquing solutions...' };
    const devSystemInstruction = `${tenetsPrefix}You are a senior software developer. You have been provided with an 'Architectural Brief' and a 'Performance Hotspot Report'.`;
    const devPrompt = `Input: The documents from Phase 1 and Phase 2.

Your Tasks:

**Propose a Solution**: Independently, create a detailed, step-by-step implementation plan to solve all issues identified in the hotspot report. Include specific code changes and justifications.

Here are the documents:
[Architectural Brief]:
---
${architecturalBrief}
---

[Performance Hotspot Report]:
---
${perfHotspotReport}
---`;
    
    // Generate 3 proposals in parallel
    const proposalPromises = [
        ai.models.generateContent({ model: MODEL_NAME, contents: devPrompt, config: { systemInstruction: devSystemInstruction } }),
        ai.models.generateContent({ model: MODEL_NAME, contents: devPrompt, config: { systemInstruction: devSystemInstruction } }),
        ai.models.generateContent({ model: MODEL_NAME, contents: devPrompt, config: { systemInstruction: devSystemInstruction } })
    ];
    const [proposal1_res, proposal2_res, proposal3_res] = await Promise.all(proposalPromises);
    const proposal1 = proposal1_res.text;
    const proposal2 = proposal2_res.text;
    const proposal3 = proposal3_res.text;
    
    yield { id: 'dev1-proposal', role: 'Senior Developer #1', content: proposal1 };
    yield { id: 'dev2-proposal', role: 'Senior Developer #2', content: proposal2 };
    yield { id: 'dev3-proposal', role: 'Senior Developer #3', content: proposal3 };

    // Generate critiques in parallel
    const critiqueSystemInstruction = `${tenetsPrefix}You are a senior software developer conducting a peer review.`;
    const createCritiquePrompt = (plan: string) => `Write a critique of the given plan. Does it address all the hotspots? Does it introduce new risks? Is there a simpler way?\n\nPlan to critique:\n---\n${plan}\n---`;

    const critiquePromises = [
        ai.models.generateContent({ model: MODEL_NAME, contents: createCritiquePrompt(proposal1), config: { systemInstruction: critiqueSystemInstruction } }),
        ai.models.generateContent({ model: MODEL_NAME, contents: createCritiquePrompt(proposal2), config: { systemInstruction: critiqueSystemInstruction } }),
        ai.models.generateContent({ model: MODEL_NAME, contents: createCritiquePrompt(proposal3), config: { systemInstruction: critiqueSystemInstruction } })
    ];
    const [critique2_res, critique3_res, critique1_res] = await Promise.all(critiquePromises);
    const critique2 = critique2_res.text; // Dev 2 critiques Dev 1
    const critique3 = critique3_res.text; // Dev 3 critiques Dev 2
    const critique1 = critique1_res.text; // Dev 1 critiques Dev 3

    yield { id: 'dev2-critique', role: 'Senior Developer #2 (Critique of #1)', content: critique2 };
    yield { id: 'dev3-critique', role: 'Senior Developer #3 (Critique of #2)', content: critique3 };
    yield { id: 'dev1-critique', role: 'Senior Developer #1 (Critique of #3)', content: critique1 };

    // --- PHASE 4: The Tech Lead ---
    yield { id: 'swarm-lead-start', role: 'Coordinator', content: 'Phase 4: Synthesis. The Tech Lead is creating the final action plan...' };
    const leadSystemInstruction = `${tenetsPrefix}You are the Tech Lead.`;
    const leadPrompt = `You have three proposed solutions and their corresponding peer reviews. Your job is to synthesize these into a single, definitive, and ordered action plan, resolving any conflicts.

Input: The three peer-reviewed plans from Phase 3.

Your Task: Create the final, canonical implementation plan as a numbered list. For each action, explain why it was chosen, referencing the peer reviews and resolving any conflicting suggestions. The plan must be ordered logically, starting with the lowest-risk changes first.

Output: The final, verified action plan.

Here are the inputs:
[PROPOSAL 1]:
${proposal1}
[CRITIQUE OF 1 (from Dev 2)]:
${critique2}

---

[PROPOSAL 2]:
${proposal2}
[CRITIQUE OF 2 (from Dev 3)]:
${critique3}

---

[PROPOSAL 3]:
${proposal3}
[CRITIQUE OF 3 (from Dev 1)]:
${critique1}
`;
    
    const finalPlanGenerator = streamResponse(leadPrompt, leadSystemInstruction, 'Tech Lead', 'final-plan');
    let result = await finalPlanGenerator.next();
    while (!result.done) {
        yield result.value;
        result = await finalPlanGenerator.next();
    }
    const finalReport = result.value;
    yield { id: 'final-plan', role: 'Tech Lead', content: finalReport, isFinal: true };
}