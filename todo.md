# **TODO:**

- [ ] type of channel called "DM" which is quite literally a single DM channel between myself and one other minion . color coordinate / add sectioned areas to separate the DM's , group chats, and autonomous chats in the channel list bar.

- [ ] channel membership section to add new / configure minion panel. should default a new minion to all group and autonomous chats, obviously not other DM's, but should create a new DM channel for the new minion automatically upon it's spawning

- [ ] fix the fucking text input area display thing + automatically keep the text input blinking cursor active instead of needing to click each damned time after sending a msg

- [ ] make the blinking cursor fucking change colors and look cool as fuck

- [ ] minion config modal X close button on top right doesn't work lol

- [ ] allow me to fuckin type still while a msg is sending

- [ ] slightly different color themes for my sent message bubbles depending on the type of channel

- [ ] give each minion their own chat bubble and font color . give them the instruction to choose what they want to use upon their VERY FIRST message ever, and never ask them again. they should be able to respond in their first message with the color codes that they want their chat bubble to be (along with the current chat background color and the current list of other minions chat bubbles/font colors so they don't look too similar). that color question should ONLY be included in the very first message upon them being spawned and immediately be configured

- [ ] fix the use_tool ability to allow them to speak AND use tool in the same reponse. so like if i say "yo do u remember that annoying project? can u check out that directory again?", it should be able to choose both SPEAK and USE_TOOL so that it can respond to my message like "yeah duh lemme look" and also using the list_directory tool at the same time. OR it can just be like simply the use_tool and add a section for them to also prepend or append a chat message to their tool usage in that same response.

- [ ] fix how the tool_call log is shown in the chat. the text should be easy to read,. it should behave like such:
if a minion uses a tool AND includes a message in the same response, the chat message bubble should show up first, and as the tool is in the process of being used, another bubble should slide out directly below the chat message bubble, it should be a different color than the message bubble and also have a stylish indication that it's a tool bubble rather than a chat bubble, such as a subtle pulsing glow border or something, and it should slide down and be attached to the bottom edge of the chat bubble. the initial display should be a high-level message, for example:
"Minion Alpha is using tool: web_search({"query":"absurd and funny news headlines"})"
and then once the output is returned, another bubble for tool_output slides out right below the first tool_call bubble. this tool_output bubble should be the same color as the tool_call bubble, but with a different color glow. (lets say like blue pulsing glow for the tool_call 'is using tool' bubble, and green pulsing glow for the output bubble) it should initially display with like the high-level message, for example:
"[TOOL OUTPUT] Web Search Results:"
and then if i click on the tool_output bubble , it should expand down to show the full results of the tool_output, and formatted in a not fucked up sorta format, like it should be formatted as markdown if that's how the output is written, or whatevs

- [ ] fix the fucking diaries so that when i click the show diary button for any of their messages, it slides UP from the TOP edge of the chat bubble and not the bottom

- [ ] also the formatting of the view diary panel is all fucked p and like gets cut off and stuff

- [ ] include in the sys prompt an explanation of how to sequentially use tools without needing to SPEAK in between tool calls ?

- [ ] also how are the actual available mcp servers + individual tools available + individual tool descriptions being passed on to the llm's in the prompts?

- [ ] also in the minion config panel, the allowed tools section is all messed up. it lists every single tool that is vavailable from the currently running MCP servers but it lists the names and their entire descriptions for each tool which is super long and it all is in this tiny little text area that i have to scroll through and check off each tool indiviudaly.  we should make it so that it is a simple line by line checklist.  at first showing the names of the MCP servers themselves that are available.  and having that little right-facing arrow to expand the actual tools that are available within that server, also in a line by line checklist below. and the same for any of the other MCP servers. literally like a tree directory format.  and each tool should be a single line, and the actual tool description should instead just be a tooltip upon hover. BY DEFAULT, ALL MCP SERVERS (AND THEIR TOOLS) SHOULD BE MADE AVAILABLE FOR EACH NEW MINION and i can check/uncheck the entire server or individual tools based on what i want that specific minoin to have access to