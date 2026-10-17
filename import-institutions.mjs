// Repeatable institution import for the Vector Firebase project.
//
// Run only from a trusted machine with Application Default Credentials:
//   npm install
//   gcloud auth application-default login
//   EXPECTED_FIREBASE_PROJECT_ID="vector-27b07" node import-institutions.mjs
//
// The script never deletes documents and never reads or writes user profiles.

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { GoogleAuth } from "google-auth-library";

const expectedProjectId = process.env.EXPECTED_FIREBASE_PROJECT_ID?.trim();

if (!expectedProjectId) {
  throw new Error("EXPECTED_FIREBASE_PROJECT_ID must be set.");
}

if (expectedProjectId !== "vector-27b07") {
  throw new Error("Unexpected Firebase project. Import aborted.");
}

const auth = new GoogleAuth();
const actualProjectId = await auth.getProjectId();

if (!actualProjectId || actualProjectId !== expectedProjectId) {
  throw new Error(
    "Application Default Credentials belong to another or unknown project. Import aborted."
  );
}

const filePath = fileURLToPath(new URL("./institutions.seed.json", import.meta.url));
const institutions = JSON.parse(await readFile(filePath, "utf8"));
const specialtiesPath = fileURLToPath(new URL("./specialties.seed.json", import.meta.url));
const specialties = JSON.parse(await readFile(specialtiesPath, "utf8"));
const identifiers = new Set();

for (const institution of institutions) {
  const requiredStrings = ["id", "name", "type", "locality", "regionID", "sourceURL"];
  if (requiredStrings.some((field) => typeof institution[field] !== "string" || !institution[field].trim())) {
    throw new Error("An institution has a missing required string field.");
  }
  if (!["university", "college"].includes(institution.type)) {
    throw new Error(`Unsupported institution type for ${institution.id}.`);
  }
  if (identifiers.has(institution.id)) {
    throw new Error(`Duplicate institution ID: ${institution.id}.`);
  }
  identifiers.add(institution.id);
}

for (const specialty of specialties) {
  const requiredStrings = ["id", "institutionID", "name", "sourceURL"];
  if (requiredStrings.some((field) => typeof specialty[field] !== "string" || !specialty[field].trim())) {
    throw new Error("A specialty has a missing required string field.");
  }
  if (!identifiers.has(specialty.institutionID)) {
    throw new Error(`Unknown institutionID for specialty ${specialty.id}.`);
  }
}

const app = initializeApp({
  credential: applicationDefault(),
  projectId: actualProjectId,
});
const database = getFirestore(app);
const batch = database.batch();

for (const institution of institutions) {
  const { id, lastVerifiedAt, ...fields } = institution;
  const verifiedDate = new Date(`${lastVerifiedAt}T00:00:00.000Z`);
  if (Number.isNaN(verifiedDate.valueOf())) {
    throw new Error(`Invalid lastVerifiedAt for ${id}.`);
  }
  batch.set(
    database.collection("institutions").doc(id),
    {
      id,
      ...fields,
      lastVerifiedAt: Timestamp.fromDate(verifiedDate),
    },
    { merge: true }
  );
}

for (const specialty of specialties) {
  const { id, lastVerifiedAt, ...fields } = specialty;
  const verifiedDate = new Date(`${lastVerifiedAt}T00:00:00.000Z`);
  if (Number.isNaN(verifiedDate.valueOf())) {
    throw new Error(`Invalid lastVerifiedAt for ${id}.`);
  }
  batch.set(
    database.collection("specialties").doc(id),
    {
      id,
      ...fields,
      lastVerifiedAt: Timestamp.fromDate(verifiedDate),
    },
    { merge: true }
  );
}

await batch.commit();
console.log(
  `Imported or updated ${institutions.length} institutions and ${specialties.length} specialties.`
);
