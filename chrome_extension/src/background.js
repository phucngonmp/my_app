import { initializeApp } from "firebase/app";
import { getFirestore, doc, setDoc, Timestamp } from "firebase/firestore";
import { GoogleGenAI } from "@google/genai";

const firebaseConfig = {
  apiKey: "AIzaSyCMGGBZDduOwQzNpPdgIZibcCB4AFPDluA",
  authDomain: "superfoo-3f973.firebaseapp.com",
  projectId: "superfoo-3f973",
  storageBucket: "superfoo-3f973.firebasestorage.app",
  messagingSenderId: "1035666447284",
  appId: "1:1035666447284:web:f06ba6df6da1f46a79f0e1",
  measurementId: "G-JM4SNNRVKW",
};

const ai = new GoogleGenAI({
  apiKey: "AIzaSyD8DwI5G3w0JpmHDxo33qpxA1PZ-3ZeRrs",
});
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function getExampleAndMeaning(word) {
  const response = await ai.models.generateContent({
    model: "gemini-2.0-flash",
    contents: `You will receive an input which may be a single word or a phrase in English or Japanese. Return a valid JSON object with the following fields:
              - "example": A natural sentence using the input phrase in its original language.
              - "meaning": The meaning of the input phrase translated into Vietnamese (not the meaning of the example).
              - "type": Either "English" or "Japanese" — the language of the input phrase.
              - "question": A multiple-choice question testing the user's understanding of the input phrase.
              - "choices": An array of 4 choices (strings). If the input is English, choices should be in Vietnamese. If the input is Japanese, choices should be in English.
              - "correctIndex": The index (0–3) of the correct answer inside the "choices" array.

              Only respond with a valid JSON object. Do not add explanations, extra text, or formatting.

              Let's start with the input: ${word}
              `,
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
  try {
    const data = await getExampleAndMeaning(word);
    let question, choices, correctIndex;

    if (data && data.example && data.meaning && data.type) {
      example = data.example;
      meaning = data.meaning;
      type = data.type;
      question = data.question;
      choices = data.choices;
      correctIndex = data.correctIndex;
    }

    const now = new Date();
    await setDoc(doc(db, "vocab", word), {
      example,
      meaning,
      createdAt: Timestamp.fromDate(now),
      type,
      question,
      choices,
      correctIndex,
    });
    console.log(`Saved '${word}'`);
  } catch (error) {
    console.error("Failed to save word:", error.message);
  }
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
