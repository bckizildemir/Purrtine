const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { interpretTaskAssistantRequest } = require("./taskInterpreterProxy");

const REGION = "europe-west1";
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

exports.interpretTaskAssistantRequest = onCall(
  { region: REGION, secrets: [GROQ_API_KEY], enforceAppCheck: true },
  async (request) => {
    return interpretTaskAssistantRequest({
      user: { uid: request.auth?.uid },
      data: request.data,
      groqApiKey: GROQ_API_KEY.value() || process.env.GROQ_API_KEY,
    });
  }
);
