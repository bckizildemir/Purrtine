const test = require("node:test");
const assert = require("node:assert/strict");

const { interpretTaskAssistantRequest } = require("./taskInterpreterProxy");

function successFetch(content, assertions = () => {}) {
  return async (url, options) => {
    assertions(url, options);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{ message: { content } }],
      }),
    };
  };
}

function failureFetch(status, payload = { error: { message: "provider failed" } }) {
  return async () => ({
    ok: false,
    status,
    json: async () => payload,
  });
}

const feedLuna = {
  id: "task-luna",
  title: "Feed Luna",
  category: "feeding",
  isOverdue: true,
  isDueToday: false,
  cats: [{ id: "cat-luna", name: "Luna" }],
};

const feedMochi = {
  id: "task-mochi",
  title: "Feed Mochi",
  category: "feeding",
  isOverdue: false,
  isDueToday: true,
  cats: [{ id: "cat-mochi", name: "Mochi" }],
};

const baseOptions = {
  user: { uid: "user-1" },
  provider: "groq",
  model: "test-model",
  groqApiKey: "groq-key",
};

test("rejects unauthenticated requests", async () => {
  await assert.rejects(
    () => interpretTaskAssistantRequest({
      ...baseOptions,
      user: null,
      data: { text: "I fed the cats", tasks: [feedLuna] },
      fetchImpl: successFetch(JSON.stringify({ match: "none" })),
    }),
    /Authentication is required/
  );
});

test("missing provider secret returns configuration error", async () => {
  await assert.rejects(
    () => interpretTaskAssistantRequest({
      ...baseOptions,
      groqApiKey: "",
      data: { text: "I fed the cats", tasks: [feedLuna] },
      fetchImpl: successFetch(JSON.stringify({ match: "none" })),
    }),
    /GROQ_API_KEY is not configured/
  );
});

test("empty task list short-circuits to none without calling the provider", async () => {
  let called = false;
  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "I fed the cats", tasks: [] },
    fetchImpl: async () => {
      called = true;
      throw new Error("should not be called");
    },
  });

  assert.deepEqual(result, { match: "none" });
  assert.equal(called, false);
});

test("confirmed match sends json-mode request and returns validated result", async () => {
  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "I fed Luna", referenceDate: "2026-07-17T10:00:00Z", tasks: [feedLuna, feedMochi] },
    fetchImpl: successFetch(
      JSON.stringify({ match: "confirmed", command: "complete", taskId: "task-luna", catIds: ["cat-luna"] }),
      (url, options) => {
        assert.equal(url, "https://api.groq.com/openai/v1/chat/completions");
        assert.equal(options.headers.Authorization, "Bearer groq-key");
        const body = JSON.parse(options.body);
        assert.equal(body.model, "test-model");
        assert.equal(body.temperature, 0);
        assert.deepEqual(body.response_format, { type: "json_object" });
        assert.equal(body.messages[0].role, "system");
        assert.equal(body.messages[1].role, "user");
        assert.match(body.messages[1].content, /task-luna/);
      }
    ),
  });

  assert.deepEqual(result, {
    match: "confirmed",
    command: "complete",
    taskId: "task-luna",
    catIds: ["cat-luna"],
    postponeMinutes: null,
    completedForDate: null,
    notes: null,
  });
});

test("hallucinated taskId is rejected even though the shape is otherwise valid", async () => {
  await assert.rejects(
    () => interpretTaskAssistantRequest({
      ...baseOptions,
      data: { text: "I fed Luna", tasks: [feedLuna] },
      fetchImpl: successFetch(JSON.stringify({ match: "confirmed", command: "complete", taskId: "task-invented" })),
    }),
    /unknown task/
  );
});

test("catIds are filtered to only ids belonging to the matched task", async () => {
  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "I fed the cats", tasks: [feedLuna, feedMochi] },
    fetchImpl: successFetch(
      JSON.stringify({ match: "confirmed", command: "complete", taskId: "task-luna", catIds: ["cat-luna", "cat-mochi"] })
    ),
  });

  assert.deepEqual(result.catIds, ["cat-luna"]);
});

test("postpone command defaults minutes and clamps out-of-range values", async () => {
  const withoutDuration = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "remind me about Luna later", tasks: [feedLuna] },
    fetchImpl: successFetch(JSON.stringify({ match: "confirmed", command: "postpone", taskId: "task-luna" })),
  });
  assert.equal(withoutDuration.postponeMinutes, 30);

  const clamped = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "remind me about Luna in 3 days", tasks: [feedLuna] },
    fetchImpl: successFetch(
      JSON.stringify({ match: "confirmed", command: "postpone", taskId: "task-luna", postponeMinutes: 999999 })
    ),
  });
  assert.equal(clamped.postponeMinutes, 24 * 60);
});

test("clarify returns only candidate ids present in the sent task list", async () => {
  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "I fed the cats", tasks: [feedLuna, feedMochi] },
    fetchImpl: successFetch(
      JSON.stringify({
        match: "clarify",
        command: "complete",
        candidateTaskIds: ["task-luna", "task-mochi", "task-invented"],
      })
    ),
  });

  assert.deepEqual(result, { match: "clarify", command: "complete", candidateTaskIds: ["task-luna", "task-mochi"] });
});

test("clarify degrades to none when fewer than two candidates survive validation", async () => {
  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "I fed the cats", tasks: [feedLuna, feedMochi] },
    fetchImpl: successFetch(
      JSON.stringify({ match: "clarify", command: "complete", candidateTaskIds: ["task-luna", "task-invented"] })
    ),
  });

  assert.deepEqual(result, { match: "none" });
});

test("malformed JSON from the model surfaces as a data-loss error", async () => {
  await assert.rejects(
    () => interpretTaskAssistantRequest({
      ...baseOptions,
      data: { text: "I fed Luna", tasks: [feedLuna] },
      fetchImpl: successFetch("not json at all"),
    }),
    (error) => error.code === "data-loss"
  );
});

test("provider rate-limit response maps to resource-exhausted", async () => {
  await assert.rejects(
    () => interpretTaskAssistantRequest({
      ...baseOptions,
      data: { text: "I fed Luna", tasks: [feedLuna] },
      fetchImpl: failureFetch(429),
    }),
    (error) => error.code === "resource-exhausted"
  );
});

test("task list is capped and unknown categories fall back to general", async () => {
  const manyTasks = Array.from({ length: 90 }, (_, index) => ({
    id: `task-${index}`,
    title: `Task ${index}`,
    category: "not-a-real-category",
    cats: [],
  }));

  const result = await interpretTaskAssistantRequest({
    ...baseOptions,
    data: { text: "do something", tasks: manyTasks },
    fetchImpl: successFetch(JSON.stringify({ match: "confirmed", command: "complete", taskId: "task-0" }), (url, options) => {
      const body = JSON.parse(options.body);
      const parsedTasks = JSON.parse(body.messages[1].content).tasks;
      assert.equal(parsedTasks.length, 60);
      assert.equal(parsedTasks[0].category, "general");
    }),
  });

  assert.equal(result.taskId, "task-0");
});
