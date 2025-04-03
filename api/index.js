const express = require("express");
const OpenAI = require("openai");
require("dotenv").config();

const app = express();
const port = 3000;

const messageTemplates = require("./obj/messagetemplates.json");

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.API_TOKEN,
});

// Middleware for parsing JSON bodies
app.use(express.json());

// Test route
app.get("/", (req, res) => {
  res.json({ message: "API is up and running!" });
});

// Chat endpoint
app.post("/api/chat", async (req, res) => {
  try {
    const { message: gameState } = req.body;

    if (!gameState) {
      return res.status(400).json({ error: "Gamestate not found!" });
    }

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        messageTemplates.systemmsg,
        {
          role: "user",
          content:
            "Here is the current game state:\n\n" +
            JSON.stringify(gameState, null, 2), //this fix is pretty ass, but works for now
        },
      ],
    });

    const response = completion.choices[0].message.content;

    res.json({
      response: response,
    });

    console.log('Current action being taken: ' + response);
  } catch (error) {
    console.error("Error:", error);
    res.status(500).json({ error: "Failed to process request" });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
