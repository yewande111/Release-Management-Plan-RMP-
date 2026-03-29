const request = require("supertest");
const app = require("../server");

jest.mock("axios");
const axios = require("axios");

describe("Frontend Service", () => {
  test("GET /health returns UP", async () => {
    const res = await request(app).get("/health");
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe("UP");
  });

  test("GET / renders recipe list", async () => {
    axios.get.mockResolvedValue({
      data: [{ id: "1", title: "Pasta", ingredients: "Pasta, Sauce", instructions: "Boil and mix" }],
    });
    const res = await request(app).get("/");
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain("Pasta");
  });

  test("GET / handles backend error gracefully", async () => {
    axios.get.mockRejectedValue(new Error("ECONNREFUSED"));
    const res = await request(app).get("/");
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain("Unable to connect");
  });
});
