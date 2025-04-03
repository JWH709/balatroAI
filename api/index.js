const express = require('express');
const OpenAI = require('openai');
require('dotenv').config();

const app = express();
const port = 3000;

const messagesData = require('./obj/messages.json');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.API_TOKEN
});

// Middleware for parsing JSON bodies
app.use(express.json());

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to the API!' });
});

// Chat endpoint
app.post('/api/chat', async (req, res) => {
  try {
    const { message } = req.body;
    
    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [
        messagesData.systemmsg,
        messagesData.usermsg
      ],
    });

    const response = completion.choices[0].message.content;

    res.json({
      response: response
    });

    console.log(response);

  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Failed to process request' });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});