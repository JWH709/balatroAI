local mod_id = "balatrobot"

-- Get Libraries
local socket = require("mods.balatrobot.libs.luasocket.src.socket")
local http = require("mods.balatrobot.libs.luasocket.src.http")
local json = require("mods.balatrobot.libs.dkjson")
local ltn12 = require("mods.balatrobot.libs.luasocket.src.ltn12")

-- Logger
local logging = require("logging")
local logger = logging.getLogger(mod_id)

-- Console
local console = require("console")

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

-- Function to send game state to server
local function sendGameStateToServer()
    local gameState = getGameState()

    -- Encode game state as JSON
    local jsonData, err = json.encode(gameState or {}, { exception = function() return "<cycle>" end })

    if not jsonData then
        logger:error("Failed to encode game state: " .. tostring(err))
        jsonData = "{}" -- Failsafe: Send an empty object instead of `null`
    end

    -- Log formatted JSON data before sending
    logger:info("Formatted JSON Data:\n" .. jsonData)

    local url = "http://localhost:3000/game-state"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
        ["Content-Length"] = tostring(#jsonData)
    }

    -- HTTP Response Storage
    local response_body = {}

    -- Send HTTP Request
    local response, status, response_headers = http.request {
        url = url,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(jsonData),
        sink = ltn12.sink.table(response_body)
    }

    -- Log HTTP Response
    local responseText = table.concat(response_body)
    logger:info("HTTP Status: " .. tostring(status))
    logger:info("Server Response: " .. responseText)

    return true
end

-- Register command for logging game state
local function on_enable()
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
    console:removeCommand("sendGameState")
    logger:info("BalatroBot disabled")
end

return {
    on_enable = on_enable,
    on_disable = on_disable
}
