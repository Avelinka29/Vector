// Run only from a trusted machine with Application Default Credentials.
// The Firebase Authentication user must already exist.
//
// Example:
//   npm install
//   gcloud auth application-default login
//   EXPECTED_FIREBASE_PROJECT_ID="your-project-id" \
//     node set-admin.mjs admin@example.com
//
// Never pass a password to this script and never add service-account keys to
// the iOS project or repository.

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const expectedProjectId = process.env.EXPECTED_FIREBASE_PROJECT_ID?.trim();

if (!expectedProjectId) {
  throw new Error(
    "EXPECTED_FIREBASE_PROJECT_ID must be set to the Firebase Project ID."
  );
}

const argumentsAfterScript = process.argv.slice(2);

if (argumentsAfterScript.length !== 1) {
  throw new Error("Pass exactly one argument: the existing user's email.");
}

const email = argumentsAfterScript[0].trim();

if (!email || !email.includes("@")) {
  throw new Error("Pass a valid email address as the only argument.");
}

// Refuse ambiguous environment configuration before initializing Admin SDK.
// The explicit projectId below is the project targeted by Firebase Auth.
for (const variableName of ["GOOGLE_CLOUD_PROJECT", "GCLOUD_PROJECT"]) {
  const configuredProjectId = process.env[variableName]?.trim();

  if (configuredProjectId && configuredProjectId !== expectedProjectId) {
    throw new Error(
      `${variableName} does not match EXPECTED_FIREBASE_PROJECT_ID. Aborting.`
    );
  }
}

const app = initializeApp({
  credential: applicationDefault(),
  projectId: expectedProjectId,
});

if (app.options.projectId !== expectedProjectId) {
  throw new Error("Firebase Admin initialized for an unexpected project. Aborting.");
}

const auth = getAuth(app);

try {
  const user = await auth.getUserByEmail(email);
  const existingClaims = user.customClaims ?? {};

  await auth.setCustomUserClaims(user.uid, {
    ...existingClaims,
    admin: true,
  });

  console.log("The admin claim was assigned to the existing Firebase user.");
  console.log("Sign out and sign in again in Vector to refresh the ID token.");
} catch (error) {
  if (error?.code === "auth/user-not-found") {
    throw new Error(
      "The Firebase Authentication user does not exist. No changes were made."
    );
  }

  const errorCode = typeof error?.code === "string" ? ` (${error.code})` : "";
  throw new Error(`Unable to assign the admin claim${errorCode}.`);
}
