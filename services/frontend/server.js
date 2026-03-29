const express = require("express");
const axios = require("axios");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const path = require("path");
const client = require("prom-client");

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:8080";

// --- Prometheus metrics ---
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics();
const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 5],
});

// --- Security middleware ---
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
      },
    },
  })
);

// --- Rate limiting ---
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// --- Logging ---
app.use(morgan("combined"));

// --- Body parsing ---
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// --- View engine ---
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));
app.use(express.static(path.join(__dirname, "public")));

// --- Request duration tracking ---
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    end({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
  });
  next();
});

// --- Health check ---
app.get("/health", (_req, res) => {
  res.json({ status: "UP", service: "frontend", timestamp: new Date().toISOString() });
});

// --- Metrics endpoint ---
app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

// --- Routes ---

// Home — list all recipes
app.get("/", async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/api/recipes`, { timeout: 5000 });
    res.render("index", { recipes: response.data, error: null });
  } catch (err) {
    console.error("Failed to fetch recipes:", err.message);
    res.render("index", { recipes: [], error: "Unable to connect to the recipe service." });
  }
});

// Create recipe
app.post("/recipes", async (req, res) => {
  try {
    const { title, ingredients, instructions } = req.body;
    await axios.post(
      `${BACKEND_URL}/api/recipes`,
      { title, ingredients, instructions },
      { timeout: 5000 }
    );
    res.redirect("/");
  } catch (err) {
    console.error("Failed to create recipe:", err.message);
    res.redirect("/?error=create_failed");
  }
});

// Delete recipe
app.post("/recipes/:id/delete", async (req, res) => {
  try {
    await axios.delete(`${BACKEND_URL}/api/recipes/${encodeURIComponent(req.params.id)}`, {
      timeout: 5000,
    });
    res.redirect("/");
  } catch (err) {
    console.error("Failed to delete recipe:", err.message);
    res.redirect("/?error=delete_failed");
  }
});

// --- Start server ---
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Frontend service running on port ${PORT}`);
    console.log(`Backend URL: ${BACKEND_URL}`);
  });
}

module.exports = app;
