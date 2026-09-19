const express = require("express");
const os = require("os");
const app = express();

app.use(express.json());

const PORT = process.env.PORT || 3000;
const APP_NAME = process.env.APP_NAME || "todo-service";
const VERSION = process.env.VERSION || "1.0.0";

app.get("/", (req, res) => {
  res.json({
    app: APP_NAME,
    version: VERSION,
    pod: os.hostname(),
  });
});

app.get("/healthz", (req, res) => {
  try {
    res.status(200).json({
      status: "healthy",
    });
  } catch (error) {
    res.status(400).json({
      message: error,
    });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running at http://localhost:${PORT}`);
});
