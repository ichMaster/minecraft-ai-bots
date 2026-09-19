// Source of truth for mindcraft/settings.js.
// Edit here, then run scripts/deploy.sh. Never edit mindcraft/settings.js directly.
const settings = {
    "minecraft_version": "1.21.6", // must be a version mineflayer supports (mindcraft README: up to 1.21.11, recommends 1.21.6)
    "host": "127.0.0.1",
    "port": 25565,
    "auth": "offline", // local test server runs online-mode=false

    "mindserver_port": 8080,
    "auto_open_ui": true,

    "base_profile": "assistant",
    "profiles": [
        "./profiles/custom/porter.json",
        "./profiles/custom/miner.json",
        "./profiles/custom/guard.json",
    ],

    "load_memory": false,
    "init_message": "Привітайся одним реченням і назви свою роль.",
    // Порожній список = слухати всіх у загальному чаті. При роздільному запуску ботів
    // (start-bot.sh) кожен вважає, що він на сервері сам, і починає реагувати на службові
    // репліки інших ботів, а ті - у відповідь. Щоб це припинити, вписати сюди свій нік:
    // "only_chat_with": ["ichland33"],
    "only_chat_with": [],

    // TTS: голос береться з "speak_model" профілю того бота, який говорить.
    // Кожен бот - окремий процес зі своєю чергою озвучування, тому одночасні
    // репліки двох ботів накладаються; різні голоси роблять це стерпним.
    "speak": false,
    "chat_ingame": true,
    "language": "en", // no auto-translation layer; the role prompts make the bots answer in Ukrainian
    "render_bot_view": false,

    // Stage 1: no runtime code generation. Builder in stage 2 is the only exception.
    "allow_insecure_coding": false,
    "allow_vision": false,

    // blocked_actions is GLOBAL in mindcraft - it cannot be set per profile.
    // Only put here what no stage-1 role may ever do; per-role limits live in each prompt.
    "blocked_actions": [
        "!checkBlueprint",
        "!checkBlueprintLevel",
        "!getBlueprint",
        "!getBlueprintLevel",
        "!newAction",    // code generation, disabled for all of stage 1
        "!attackPlayer", // no role may attack players
        // !goal/!endGoal turn on self-prompting: the bot keeps setting itself new tasks and
        // acts without being asked. Blocked to keep stage-1 behaviour predictable, not to save
        // quota - quota is not a constraint on this key. Stage 3 (Coordinator) needs them back.
        "!goal",
        "!endGoal",
    ],
    "code_timeout_mins": -1,
    "relevant_docs_count": 5,

    "max_messages": 15,
    "num_examples": 2,
    "max_commands": -1,
    "show_command_syntax": "full",
    "narrate_behavior": true,
    "chat_bot_messages": true,

    "spawn_timeout": 30,
    "block_place_delay": 0,

    "log_all_prompts": false,
};

export default settings;
