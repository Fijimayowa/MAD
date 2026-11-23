// From test_rules/: npm install
// From project root: firebase emulators:exec --only firestore "cd test_rules && npm test"
const test = require('node:test');
const fs = require('fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } = require('firebase/firestore');

let env;
test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-message-board',
    firestore: { rules: fs.readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
test.after(() => env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'messages/m1'), {
      text: 'hello', authorUid: 'ada', authorName: 'Ada L', createdAt: new Date(),
    });
  });
});

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const newMsg = (uid) => ({ text: 'hi', authorUid: uid, authorName: 'X Y', createdAt: serverTimestamp() });

test('signed-out read is denied', () => assertFails(getDoc(doc(db(), 'messages/m1'))));
test('signed-in read is allowed', () => assertSucceeds(getDoc(doc(db('bob'), 'messages/m1'))));
test('forged authorUid create is denied', () => assertFails(setDoc(doc(db('bob'), 'messages/m2'), newMsg('ada'))));
test('author create is allowed', () => assertSucceeds(setDoc(doc(db('bob'), 'messages/m2'), newMsg('bob'))));
test('cross-uid update is denied', () =>
  assertFails(updateDoc(doc(db('bob'), 'messages/m1'), { text: 'hacked', editedAt: serverTimestamp() })));
test('author update is allowed', () =>
  assertSucceeds(updateDoc(doc(db('ada'), 'messages/m1'), { text: 'edit', editedAt: serverTimestamp() })));
test('cross-uid delete is denied', () => assertFails(deleteDoc(doc(db('bob'), 'messages/m1'))));
test('author delete is allowed', () => assertSucceeds(deleteDoc(doc(db('ada'), 'messages/m1'))));
test('user record: owner create allowed with all five fields', () =>
  assertSucceeds(setDoc(doc(db('ada'), 'users/ada'), {
    uid: 'ada', firstName: 'Ada', lastName: 'L', role: 'student', registrationDateTime: serverTimestamp(),
  })));
test("another user's record is unreadable", () => assertFails(getDoc(doc(db('bob'), 'users/ada'))));
