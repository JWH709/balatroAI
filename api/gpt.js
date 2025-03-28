const fetch = require('node-fetch');

const testJson = '{"jokers":[],"stake":1,"win_ante":8,"hands_played":0,"round":1,"current_round":{"reroll_cost_increase":0,"jokers_purchased":0,"reroll_cost":5,"discards_left":3,"ancient_card":{"suit":"Hearts"},"discards_used":0,"hands_played":0,"dollars":0,"voucher":"v_hieroglyph","round_dollars":0,"mail_card":{"rank":"2","id":2},"cards_flipped":0,"current_hand":{"chip_text":"0","handname_text":"","handname":"","hand_level":"","mult":0,"mult_text":"0","chip_total_text":"","chips":0,"chip_total":0},"idol_card":{"rank":"6","suit":"Diamonds","id":6},"most_played_poker_hand":"High Card","castle_card":{"suit":"Clubs"},"round_text":"Round ","hands_left":4,"used_packs":[],"free_rerolls":0,"dollars_to_be_earned":"$$$"},"hand":{"cards":[{"rank":"King","suit":"Hearts","times_played":0,"id":13},{"rank":"Queen","suit":"Spades","times_played":0,"id":12},{"rank":"9","suit":"Hearts","times_played":0,"id":9},{"rank":"8","suit":"Clubs","times_played":0,"id":8},{"rank":"6","suit":"Clubs","times_played":0,"id":6},{"rank":"6","suit":"Diamonds","times_played":0,"id":6},{"rank":"4","suit":"Clubs","times_played":0,"id":4},{"rank":"2","suit":"Diamonds","times_played":0,"id":2}],"count":8},"deck_size":44,"unused_discards":0,"blind":{"chips_needed":300,"name":"Small Blind","debuffs":[]},"modifiers":{"money_per_hand":2,"no_interest":true,"money_per_discard":1}} '

// make fetch req
fetch('http://localhost:3000/api/chat', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message: "Hello! I am making you play balatro now. Here is my game state in raw JSON, please change this JSON and tell me how you would make the next move. Your response must be ENTIRELY IN JSON, AND MUST USE THIS FORMAT. Do not include any extra commentary, just edited JSON. \n" + testJson }),
})
.then(res => res.json())
.then(data => console.log(data))
.catch(err => console.error(err));