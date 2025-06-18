import { initializeApp } from "firebase/app";
import { getFirestore, doc, setDoc, Timestamp } from "firebase/firestore";
import { GoogleGenAI } from "@google/genai";

const firebaseConfig = {
  apiKey: "your firebase config",
  authDomain: "your firebase config",
  projectId: "your firebase config",
  storageBucket: "your firebase config",
  messagingSenderId: "your firebase config",
  appId: "your firebase config",
};

const ai = new GoogleGenAI({
  apiKey: "your gemini api key",
});
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function getExampleAndMeaning(word) {
  const response = await ai.models.generateContent({
    model: "gemini-2.0-flash",
    contents:
      "You will receive an input which may be a single word or a phrase in English or Japanese. Return a JSON object with:" +
      '"example": One sentence that naturally uses the input phrase (in English or Japanese).' +
      '"meaning": The meaning of the full input phrase translated into Vietnamese (NOT THE EXAMPLE).' +
      '"type": The language of the input phrase ("English" or "Japanese").' +
      'Only respond with a valid JSON object. Do not add explanations or extra text. Example input:"hello world"; Example output:' +
      '{"example": "Hello world, how are you?", "meaning": "Xin chào thế giới", "type": "English"}.' +
      "Let's start with the input: " +
      word,
  });
  const text = cleanResponseText(response.text);
  try {
    const data = JSON.parse(text);
    console.log("Parsed JSON:", data);
    return data;
  } catch (error) {
    console.error("❌ Failed to parse JSON:", text);
    return null;
  }
}
function cleanResponseText(text) {
  return text
    .replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();
}

async function saveWordToFirestore(
  word,
  example = "",
  meaning = "",
  type = "English"
) {
  const data = await getExampleAndMeaning(word);
  if (data && data.example && data.meaning && data.type) {
    example = data.example;
    meaning = data.meaning;
    type = data.type;
  }
  const now = new Date();
  await setDoc(doc(db, "vocab", word), {
    example,
    meaning,
    createdAt: Timestamp.fromDate(now),
    type,
  });
  console.log(`Saved '${word}'`);
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "saveSelectedText",
    title: "Save selected text",
    contexts: ["selection"],
  });
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === "saveSelectedText") {
    saveWordToFirestore(info.selectionText);
  }
});
