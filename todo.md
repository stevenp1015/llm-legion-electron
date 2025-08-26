# **TODO:**

* *note, framer-motion recently branched and is now "motion" , you can use the context7 mcp tool to find the motion react docs


- [ ] theres currently a fade effect for the chat window area to transition when i navigate to a different channel , as well as the highlighted channel on the channel list. i wanna change that to a cooler fucking effect that isn't a dumb boring fade

- [ ] option to fucking DELETE a channel or clear ALL messages from one

- [ ] ability to add a sort of "sub-folder" within the chat categories. for example, within the "DM" section of the channel list, i can add a folder of "direct reports" or something and move chats into that little folder section that i can fold / unfold to keep it organized and clean 

- [ ] when clicking the new channel button, the list of participants should start wihtout anyone checked, and also have a "check/uncheck all" button thing

- [ ] for some reason, the incoming messages will like partially repeat the end of them. for example: "Anyway, I'm thinking a sick orange for my colors.sick orange for my colors. " 

- [ ] what the hell is the deal with the text streaming? it doesn't work consistently, if at all

- [ ] Improve the display of tool_call logs in the chat. The text should be easy to read and behave as follows:
        - [ ] If a minion uses a tool and includes a chat message in the same response, the chat message bubble should appear first. As the tool is being used, another bubble should slide out directly below it, attached to the bottom edge of the chat bubble. This "tool_call" bubble should be a different color than the chat bubble, and should include a stylish indication that displays *while the tool is actively being used*, such as a subtle pulsing glow on the bottom edge of the "tool_call" bubble.
        - [ ] Initially, it should display a high-level message, for example: "Minion Alpha is using tool: web_search"
        - [ ] If that "tool_call" bubble is clicked, it should expand to display the paramters or details of the tool call, for example: "<web_search> ({"query":"absurd and funny news headlines"})"
        - [ ] Once the output returns, the pulsing glow should stop pulsing and just be a static color, and a "tool_output" bubble should slide out right below the first "tool_call" bubble. This "tool_output" bubble should be a similar color as the "tool_call" bubble, maybe a shade darker to indicate it's complete nature.
        - [ ] The "tool_output" bubble should initially display a high-level message, such as: "[TOOL OUTPUT] Web Search Results:"
        - [ ] If the user clicks on the "tool_output" bubble, it should expand to display the full results. The formatting should be clear and correct; for example, if the output is Markdown, it should be rendered as such.

- [ ] also how are the actual available mcp servers + individual tools available + individual tool descriptions being passed on to the llm's in the prompts? i think they're by default sending allllll of the tool descriptions for every tool that is available, which is a fucking LOT of unncessary context saturation when not using tools.  is there a possible way to like indicate in the system message that like if instructed to use a tool, use <available_tools> or some shit to display the list of tools they have access to, instead of lit dumping the entire thing on them every single turn? (we would need to also implement this <available_tools> function somehow) 

- [x] type of channel called "DM" which is quite literally a single DM channel between myself and one other minion . 

- [x] add sectioned areas to separate the DM's , group chats, and autonomous chats in the channel list bar.

- [x] in the channel list, when the current open chat is a DM, have the background color for currently open channel button thing on the channel list be team-600

- [x] fix the fucking text input area display thing + automatically keep the text input blinking cursor active instead of needing to click each damned time after sending a msg

- [x] make the blinking cursor fucking change colors and look cool as fuck

- [x] minion config modal X close button on top right doesn't work lol

- [x] allow me to fuckin type still while a msg is sending

- [x] slightly different color themes for my sent message bubbles depending on the type of channel

- [x] give each minion their own chat bubble and font color . give them the instruction to choose what they want to use upon their VERY FIRST message ever, and never ask them again. they should be able to respond in their first message with the color codes that they want their chat bubble to be (along with the current chat background color and the current list of other minions chat bubbles/font colors so they don't look too similar). that color question should ONLY be included in the very first message upon them being spawned and immediately be configured

- [x] fix the use_tool ability to allow them to speak AND use tool in the same reponse. so like if i say "yo do u remember that annoying project? can u check out that directory again?", it should be able to choose both SPEAK and USE_TOOL so that it can respond to my message like "yeah duh lemme look" and also using the list_directory tool at the same time. OR it can just be like simply the use_tool and add a section for them to also prepend or append a chat message to their tool usage in that same response.

- [x] fix the fucking diaries so that when i click the show diary button for any of their messages, it slides UP from the TOP edge of the chat bubble and not the bottom

- [x] also the formatting of the view diary panel is all fucked p and like gets cut off and stuff

- [x] include in the sys prompt an explanation of how to sequentially use tools without needing to SPEAK in between tool calls ?

- [x] also in the minion config panel, the allowed tools section is all messed up. it lists every single tool that is vavailable from the currently running MCP servers but it lists the names and their entire descriptions for each tool which is super long and it all is in this tiny little text area that i have to scroll through and check off each tool indiviudaly.  we should make it so that it is a simple line by line checklist.  at first showing the names of the MCP servers themselves that are available.  and having that little right-facing arrow to expand the actual tools that are available within that server, also in a line by line checklist below. and the same for any of the other MCP servers. literally like a tree directory format.  and each tool should be a single line, and the actual tool description should instead just be a tooltip upon hover. BY DEFAULT, ALL MCP SERVERS (AND THEIR TOOLS) SHOULD BE MADE AVAILABLE FOR EACH NEW MINION and i can check/uncheck the entire server or individual tools based on what i want that specific minoin to have access to

