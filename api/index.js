const express = require('express');
const app = express();
const port = 3000;

// Middleware for parsing JSON bodies
app.use(express.json());

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to the API!' });
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
