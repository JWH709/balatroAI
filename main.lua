local mod_id = "balatrobot"

-- Initialize logger first
local logging = require("logging")
local logger = logging.getLogger(mod_id)

-- Function to safely require libraries
local function safe_require(path)
    local success, result = pcall(require, path)
    if not success then
        logger:error("Failed to load library: " .. path .. " - " .. tostring(result))
        return nil
    end
    return result
end

-- Get Libraries
local socket = safe_require("mods.balatrobot.libs.luasocket.src.socket")
local ltn12 = safe_require("mods.balatrobot.libs.luasocket.src.ltn12")
local mime = safe_require("mods.balatrobot.libs.luasocket.src.mime")
local http = safe_require("mods.balatrobot.libs.luasocket.src.http")
local json = safe_require("mods.balatrobot.libs.dkjson")

-- Console
local console = safe_require("console")

-- Function to extract game state
local function getGameState()
    if not G or not G.GAME then 
        logger:error("G or G.GAME is nil! Returning empty game state.")
        return {} 
    end

    local gameState = {
        stake = G.GAME.stake or 0,
        unused_discards = G.GAME.unused_discards or 0,
        win_ante = G.GAME.win_ante or 0,
        round = G.GAME.round or 0,
        hands_played = G.GAME.hands_played or 0,

        -- Current round state
        current_round = G.GAME.current_round or {},

        -- Active modifiers
        modifiers = G.GAME.modifiers or {},

        -- Jokers in play
        jokers = {},

        -- Blind (round effect)
        blind = {
            name = G.GAME.round_resets and G.GAME.round_resets.blind and G.GAME.round_resets.blind.name or "Unknown",
            debuffs = G.GAME.round_resets and G.GAME.round_resets.blind and G.GAME.round_resets.blind.debuff or {},
            chips_needed = (G.GAME.round_resets and G.GAME.round_resets.blind and G.GAME.round_resets.blind.mult or 1) * 300,
        },

        -- Deck info
        deck_size = G.deck and #G.deck.cards or 0,

        -- Current hand details
        hand = {
            cards = {},
            count = 0
        }
    }

    -- Extract Joker Data
    if G.jokers and G.jokers.cards then
        for _, joker in ipairs(G.jokers.cards) do
            table.insert(gameState.jokers, {
                name = joker.label or "Unknown",
                effect = joker.ability and joker.ability.effect or "None",
                multiplier = joker.ability and joker.ability.mult or 1,
                times_used = joker.base and joker.base.times_played or 0
            })
        end
    end

    -- Extract Hand Data
    if G.hand and G.hand.cards then
        for _, card in ipairs(G.hand.cards) do
            table.insert(gameState.hand.cards, {
                rank = card.base and card.base.value or "Unknown",
                suit = card.base and card.base.suit or "Unknown",
                id = card.base and card.base.id or -1,
                times_played = card.base and card.base.times_played or 0
            })
        end
        gameState.hand.count = #gameState.hand.cards
    end

    return gameState
end

-- Function to execute bot decisions
local function executeBotDecision(decision)
    if not decision or not decision.action then
        logger:error("Invalid decision format")
        return false
    end

    logger:info("Executing bot decision: " .. json.encode(decision))

    -- Handle different types of actions
    if decision.action == "discard" then
        -- Only allow discarding if we're in the right state and have discards left
        if G.GAME.current_round and G.GAME.current_round.discards_left > 0 then
            -- Handle discarding cards
            if decision.cards and #decision.cards > 0 then
                -- First highlight the cards we want to discard
                for _, cardId in ipairs(decision.cards) do
                    -- Find the card in the hand
                    for _, card in ipairs(G.hand.cards) do
                        if card.base and card.base.id == cardId then
                            -- Highlight the card
                            G.hand:add_to_highlighted(card)
                            logger:info("Highlighting card: " .. card.base.value .. " of " .. card.base.suit)
                        end
                    end
                end

                -- Then trigger the discard action
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.1,
                    blocking = true,
                    blockable = false,
                    func = function()
                        if G.FUNCS.discard_cards_from_highlighted then
                            G.FUNCS.discard_cards_from_highlighted()
                        end
                        return true
                    end
                }))
                return true
            end
        else
            logger:error("Cannot discard - no discards left or wrong game state")
        end
    elseif decision.action == "reroll" then
        -- Only allow rerolling if we're in the shop phase
        if G.STATE == G.STATES.SHOP then
            -- Handle rerolling the shop
            if G.GAME.current_round and G.GAME.current_round.reroll_cost then
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.1,
                    blocking = true,
                    blockable = false,
                    func = function()
                        if G.GAME.current_round then
                            G.GAME.current_round:reroll_shop()
                        end
                        return true
                    end
                }))
                return true
            end
        else
            logger:error("Cannot reroll - not in shop phase")
        end
    elseif decision.action == "buy_joker" then
        -- Only allow buying jokers if we're in the shop phase
        if G.STATE == G.STATES.SHOP then
            -- Handle buying a joker
            if decision.joker_index then
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.1,
                    blocking = true,
                    blockable = false,
                    func = function()
                        if G.GAME.current_round then
                            G.GAME.current_round:buy_joker(decision.joker_index)
                        end
                        return true
                    end
                }))
                return true
            end
        else
            logger:error("Cannot buy joker - not in shop phase")
        end
    end

    return false
end

-- Function to send game state to server
local function sendGameStateToServer()
    if not json then
        logger:error("JSON library not loaded!")
        return false
    end

    local gameState = getGameState()

    -- Encode game state as JSON
    logger:info("Attempting to encode game state...")
    logger:info("Json library status: " .. tostring(json ~= nil))
    logger:info("Json library type: " .. type(json))
    logger:info("Json library methods: " .. tostring(json and json.encode ~= nil))
    
    if not json.encode then
        logger:error("JSON library encode method is nil!")
        return false
    end

    local jsonData, err = json.encode(gameState or {}, { exception = function() return "<cycle>" end })

    if not jsonData then
        logger:error("Failed to encode game state: " .. tostring(err))
        jsonData = "{}" -- Failsafe: Send an empty object instead of `null`
    end

    -- Log formatted JSON data before sending
    logger:info("Formatted JSON Data:\n" .. jsonData)

    local url = "http://localhost:3000/api/chat"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    }

    -- HTTP Response Storage
    local response_body = {}

    -- Prepare message for GPT with more structured instructions
    local requestBody = {
        message = [[You are a Balatro bot that needs to make decisions about the game. Analyze the current game state and respond with a JSON object that includes:
1. action: The type of action to take ("discard", "reroll", "buy_joker")
2. cards: Array of card IDs to discard (if action is "discard")
3. joker_index: Index of joker to buy (if action is "buy_joker")
4. reasoning: Brief explanation of why this decision was made

IMPORTANT GAME RULES:
GAME PHASES:
- During the hand phase (when you have cards in hand):
  * CRITICAL: If discards_left = 0, you MUST play the hand - you cannot discard or reroll
  * Only if discards_left > 0 can you consider discarding cards
  * Only discard if you can significantly improve the hand (e.g., from high card to two pair or better)
  * If you have a good hand (two pair or better), play it instead of discarding
- During the shop phase (when you can buy jokers):
  * You can reroll the shop to get new jokers
  * You can buy jokers from the shop
  * You CANNOT discard or play cards in the shop phase

CURRENT DISCARDS STATUS:
]] .. (G.GAME.current_round and G.GAME.current_round.discards_left == 0 and [[
WARNING: You have NO discards left! You MUST play the current hand - discarding is not an option.
]] or [[
You have ]] .. (G.GAME.current_round and G.GAME.current_round.discards_left or 0) .. [[ discards remaining.
]]) .. [[

Current game state:
]] .. jsonData
    }

    -- Send HTTP Request
    logger:info("Attempting to send HTTP request to: " .. url)
    logger:info("Request headers: " .. json.encode(headers))
    logger:info("Request body: " .. json.encode(requestBody))
    
    local success, response, status, response_headers = pcall(function()
        return http.request {
            url = url,
            method = "POST",
            headers = headers,
            source = ltn12.source.string(json.encode(requestBody)),
            sink = ltn12.sink.table(response_body)
        }
    end)

    if not success then
        logger:error("HTTP request failed: " .. tostring(response))
        return false
    end

    -- Log HTTP Response
    local responseText = table.concat(response_body)
    logger:info("HTTP Status: " .. tostring(status))
    logger:info("HTTP Response Headers: " .. tostring(response_headers))
    logger:info("Server Response: " .. responseText)

    if status ~= 200 then
        logger:error("HTTP request failed with status: " .. tostring(status))
        logger:error("Full response: " .. responseText)
        return false
    end

    -- Try to parse the response
    if responseText and responseText ~= "" then
        local success, responseData = pcall(json.decode, responseText)
        if success and responseData and responseData.response then
            logger:info("GPT Response: " .. responseData.response)
            
            -- Try to parse the decision from the response
            local decisionSuccess, decision = pcall(json.decode, responseData.response)
            if decisionSuccess and decision then
                logger:info("Parsed decision: " .. json.encode(decision))
                -- Execute the bot's decision
                executeBotDecision(decision)
            else
                logger:error("Failed to parse decision from response")
            end
        end
    end

    return true
end

-- Register command for logging game state
local function on_enable()
    if not console then
        logger:error("Console library not loaded!")
        return
    end

    console:registerCommand(
        "sendGameState",
        sendGameStateToServer,
        "Sends the current game state to the server",
        function() return {} end,
        "sendGameState"
    )
    logger:info("BalatroBot enabled - sendGameState command registered")
end

-- Remove command on disable
local function on_disable()
    if console then
        console:removeCommand("sendGameState")
        logger:info("BalatroBot disabled")
    end
end

return {
    on_enable = on_enable,
    on_disable = on_disable
}
